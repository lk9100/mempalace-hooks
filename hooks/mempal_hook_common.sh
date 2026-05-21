#!/bin/bash
# Shared helpers for MemPalace shell hooks.

mempal_normalize_wing_name() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E \
        -e 's/[ -]+/_/g' \
        -e 's/[^a-z0-9_]+/_/g' \
        -e 's/^_+//' \
        -e 's/_+$//' \
        -e 's/__+/_/g'
}

mempal_target_wing() {
    local transcript_path="$1"

    [ -n "$transcript_path" ] || return 1

    "$MEMPAL_PYTHON_BIN" - "$transcript_path" <<'PY'
import json
import os
import re
import sys


def normalize(name: str) -> str:
    name = name.strip().lower().replace(" ", "_").replace("-", "_")
    name = re.sub(r"[^a-z0-9_]+", "_", name).strip("_")
    return name


path = sys.argv[1]

try:
    with open(path, encoding="utf-8", errors="replace") as f:
        for idx, line in enumerate(f):
            try:
                obj = json.loads(line)
            except Exception:
                continue

            cwd = ""
            if isinstance(obj, dict):
                if isinstance(obj.get("cwd"), str):
                    cwd = obj["cwd"]
                if not cwd:
                    payload = obj.get("payload")
                    if isinstance(payload, dict) and isinstance(payload.get("cwd"), str):
                        cwd = payload["cwd"]

            if cwd:
                wing = normalize(os.path.basename(os.path.normpath(cwd)))
                if wing:
                    print(wing)
                    raise SystemExit(0)

            if idx >= 20:
                break
except OSError:
    pass

normalized_path = path.replace("\\", "/")
match = re.search(r"/\.claude/projects/-([^/]+)", normalized_path)
if match:
    encoded = match.group(1)
    project = encoded.rsplit("-", 1)[-1]
    wing = normalize(project)
    if wing:
        print(wing)
        raise SystemExit(0)

# Explicit fallback for ambiguous/unscoped chat transcripts. Avoids
# polluting the palace with transcript storage folder names like dates.
print("codex_sessions_unscoped")
PY
}

mempal_count_human_messages() {
    local transcript_path="$1"

    if [ ! -f "$transcript_path" ]; then
        echo "0"
        return 0
    fi

    "$MEMPAL_PYTHON_BIN" - "$transcript_path" <<'PY'
import json
import sys

count = 0

with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
    for line in f:
        try:
            entry = json.loads(line)
        except Exception:
            continue

        msg = entry.get("message", {})
        if isinstance(msg, dict) and msg.get("role") == "user":
            content = msg.get("content", "")
            if isinstance(content, list):
                content = " ".join(
                    block.get("text", "") for block in content if isinstance(block, dict)
                )
            if isinstance(content, str):
                if "<command-message>" in content or "<system-reminder>" in content:
                    continue
                if content.strip():
                    count += 1
            continue

        if entry.get("type") == "event_msg":
            payload = entry.get("payload", {})
            if isinstance(payload, dict) and payload.get("type") == "user_message":
                text = payload.get("message", "")
                if isinstance(text, str) and text.strip() and "<command-message>" not in text:
                    count += 1

print(count)
PY
}

mempal_prepare_transcript_stage() {
    local transcript_path="$1"
    local session_id="$2"
    local stage_root="$STATE_DIR/staged_transcripts"
    local stage_dir
    local staged_file

    mkdir -p "$stage_root" || return 1

    if ! stage_dir=$(mktemp -d "$stage_root/${session_id}.XXXXXX" 2>/dev/null); then
        return 1
    fi

    staged_file="$stage_dir/$(basename "$transcript_path")"
    if ! ln -f "$transcript_path" "$staged_file" 2>/dev/null; then
        if ! cp -f "$transcript_path" "$staged_file"; then
            rm -rf "$stage_dir"
            return 1
        fi
    fi

    printf '%s\n' "$stage_dir"
}

mempal_mine_active_transcript() {
    local transcript_path="$1"
    local session_id="$2"
    local log_file="$3"
    local mode="$4"
    local stage_dir
    local wing
    local mine_args=()

    if ! is_valid_transcript_path "$transcript_path" || [ ! -f "$transcript_path" ]; then
        return 1
    fi

    wing="$(mempal_target_wing "$transcript_path")"
    stage_dir="$(mempal_prepare_transcript_stage "$transcript_path" "$session_id")" || {
        echo "[$(date '+%H:%M:%S')] Failed to stage transcript for session $session_id" >> "$log_file"
        return 1
    }

    mine_args=("$stage_dir" --mode convos)
    if [ -n "$wing" ]; then
        mine_args+=(--wing "$wing")
        echo "[$(date '+%H:%M:%S')] Mining active transcript for session $session_id into wing $wing" >> "$log_file"
    else
        echo "[$(date '+%H:%M:%S')] Mining active transcript for session $session_id with default wing" >> "$log_file"
    fi

    if [ "$mode" = "async" ]; then
        if [ -n "$wing" ]; then
            nohup env \
                MEMPAL_STAGE_DIR="$stage_dir" \
                MEMPAL_TARGET_WING="$wing" \
                MEMPAL_HOOK_LOG="$log_file" \
                bash -c '
                    mempalace mine "$MEMPAL_STAGE_DIR" --mode convos --wing "$MEMPAL_TARGET_WING" >> "$MEMPAL_HOOK_LOG" 2>&1
                    rm -rf "$MEMPAL_STAGE_DIR"
                ' >/dev/null 2>&1 &
        else
            nohup env \
                MEMPAL_STAGE_DIR="$stage_dir" \
                MEMPAL_HOOK_LOG="$log_file" \
                bash -c '
                    mempalace mine "$MEMPAL_STAGE_DIR" --mode convos >> "$MEMPAL_HOOK_LOG" 2>&1
                    rm -rf "$MEMPAL_STAGE_DIR"
                ' >/dev/null 2>&1 &
        fi
    else
        mempalace mine "${mine_args[@]}" >> "$log_file" 2>&1
        rm -rf "$stage_dir"
    fi
}
