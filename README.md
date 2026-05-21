# MemPalace Hooks Fork

Standalone shell-hook bundle for Claude Code and Codex, extracted into its own
repo so it can be installed, reviewed, and maintained without needing a full
MemPalace checkout.

This repo is intentionally a fork of the upstream MemPalace shell-hook shape in
[`MemPalace/mempalace`](https://github.com/MemPalace/mempalace), specifically
the original standalone hooks under
[`develop/hooks`](https://github.com/MemPalace/mempalace/tree/develop/hooks).
It exists because the local workflow here needed a few behavior changes that
were important enough to preserve explicitly instead of carrying an opaque copy
inside a dotfiles directory.

## Why This Fork Exists

Upstream MemPalace ships hook support, but this repo keeps a small,
purpose-built fork of the shell hooks so the behavior stays obvious and easy to
reuse later.

The fork exists to make four things explicit:

- project conversations should land in the correct palace wing when a project
  wing already exists
- ambiguous home-directory or unscoped sessions should not pollute the palace
  with transcript-folder names
- only the active transcript should be mined during hook execution
- Codex transcript shapes and compaction timing should be handled correctly

## How This Differs From Upstream `develop/hooks`

Compared with the upstream shell hooks in
[`develop/hooks`](https://github.com/MemPalace/mempalace/tree/develop/hooks),
this fork intentionally changes behavior in these ways:

- **Project-aware wing routing**
  The target wing is derived from transcript `cwd`, normalized, and used only
  when that wing already exists in the palace. Otherwise the hooks fall back to
  `codex_sessions_unscoped`.
- **Active-transcript-only mining**
  The hooks stage and mine only the current transcript instead of sweeping a
  broader transcript directory during hook execution.
- **Codex-aware human-message counting**
  The save hook counts both standard user messages and Codex
  `event_msg`/`user_message` transcript entries.
- **Synchronous correctness on save/compact boundaries**
  `PreCompact` always mines synchronously, and the save path prioritizes correct
  checkpoint behavior over maximizing parallelism.
- **Self-contained maintenance target**
  This repo keeps the hook bundle and docs together so future updates can be
  compared directly against upstream without depending on one person's local
  machine layout.

For update guidance, see [docs/UPSTREAM_NOTES.md](docs/UPSTREAM_NOTES.md).

## Repo Contents

This repo is intentionally small:

- `hooks/mempal_save_hook.sh`
- `hooks/mempal_precompact_hook.sh`
- `hooks/mempal_hook_common.sh`
- `README.md`
- `docs/UPSTREAM_NOTES.md`

All three shell scripts are required. The two entrypoint hooks source
`mempal_hook_common.sh`.

## Runtime Requirements

- `mempalace` CLI available on `PATH`
- Python 3 available on `PATH`
- an initialized MemPalace install with a readable palace

Optional environment overrides:

- `MEMPAL_PYTHON` to force a specific Python interpreter
- `MEMPAL_DIR` to additionally mine a project directory with `--mode projects`

The scripts also prepend `~/.local/bin` to `PATH` so `uv tool install`
deployments remain visible to GUI-launched apps.

## Install

Make the entrypoint scripts executable:

```bash
chmod +x hooks/mempal_save_hook.sh hooks/mempal_precompact_hook.sh
```

Pick an absolute path to this repo and use that same path in the client hook
config. The repo does not need to live in any specific home-directory location.

### Claude Code

Add to `~/.claude/settings.local.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/mempalace-hooks/hooks/mempal_save_hook.sh",
            "timeout": 30
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "/absolute/path/to/mempalace-hooks/hooks/mempal_precompact_hook.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Codex

Add to `~/.codex/hooks.json`:

```json
{
  "Stop": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "/absolute/path/to/mempalace-hooks/hooks/mempal_save_hook.sh",
          "timeout": 30
        }
      ]
    }
  ],
  "PreCompact": [
    {
      "hooks": [
        {
          "type": "command",
          "command": "/absolute/path/to/mempalace-hooks/hooks/mempal_precompact_hook.sh",
          "timeout": 30
        }
      ]
    }
  ]
}
```

## Behavior Summary

### Stop

- runs after an assistant turn ends
- counts human messages in the transcript
- triggers every `SAVE_INTERVAL` messages, default `3`
- mines only the active transcript into the derived project wing when that
  wing already exists in the palace, or into `codex_sessions_unscoped`
- is quiet by default unless `MEMPAL_VERBOSE=true`

### PreCompact

- runs before compaction
- mines only the active transcript into the derived project wing when that wing
  already exists, or into `codex_sessions_unscoped`
- always runs synchronously
- always returns `{}` and does not use the Stop-hook block protocol

## Config Knobs

The shipped defaults live in the shell scripts:

- `SAVE_INTERVAL=3`
- `STATE_DIR="$HOME/.mempalace/hook_state"`
- fallback wing = `codex_sessions_unscoped`

Common knobs you may want to edit:

- `SAVE_INTERVAL`
- `STATE_DIR`
- `MEMPAL_DIR`
- `MEMPAL_VERBOSE`
- `MEMPAL_PYTHON`

`MEMPAL_DIR` is additive. It does not replace transcript mining.

## State And Logs

Hook runtime state is written to:

```bash
~/.mempalace/hook_state/
```

That directory typically contains:

- `hook.log`
- `*_last_save`
- staged transcript temp directories during mining
- parse diagnostics on failure

## Upstream References

- Upstream MemPalace repo:
  [`MemPalace/mempalace`](https://github.com/MemPalace/mempalace)
- Original standalone shell-hook shape this fork tracks:
  [`develop/hooks`](https://github.com/MemPalace/mempalace/tree/develop/hooks)

This repo is not a full MemPalace mirror. It is a maintained fork of the shell
hooks plus the minimum documentation needed to understand, install, and update
them later.
