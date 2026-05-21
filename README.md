# MemPalace Hooks

Extracted, working MemPalace hook bundle for Claude Code and Codex.

This repo contains the hook scripts exactly as they are currently working on
`/Users/kailan`, with intentional behavior changes from upstream shell hooks:

- conversation memory is routed into the project wing derived from `cwd`,
  with fallback wing `codex_sessions_unscoped` when no project wing can be
  resolved
  Generic home-directory sessions are treated as unscoped and also route to
  `codex_sessions_unscoped`.
- only the active transcript is mined
- Codex `event_msg` / `user_message` transcripts are counted correctly
- `Stop` transcript mining is synchronous for correctness

## Files

- `hooks/mempal_save_hook.sh`
- `hooks/mempal_precompact_hook.sh`
- `hooks/mempal_hook_common.sh`

All three are required. The two entrypoints source `mempal_hook_common.sh`.

## Behavior

### Stop

- Fires after an assistant turn ends
- Counts user messages in the transcript
- Triggers every `SAVE_INTERVAL` messages, default `3`
- Mines only the active transcript into the derived project wing when that
  wing already exists in the palace, or into `codex_sessions_unscoped` when
  no initialized project wing can be resolved
- Silent by default unless `MEMPAL_VERBOSE=true`

### PreCompact

- Fires before compaction
- Mines only the active transcript into the derived project wing when that
  wing already exists in the palace, or into `codex_sessions_unscoped` when
  no initialized project wing can be resolved
- Always synchronous
- Always returns `{}` and does not block

## Install

Make the entrypoint scripts executable:

```bash
chmod +x hooks/mempal_save_hook.sh hooks/mempal_precompact_hook.sh
```

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

## Runtime requirements

- `mempalace` CLI must be available on `PATH`
- Python 3 must be available
- `MEMPAL_PYTHON` can be used to override interpreter selection

The scripts also prepend `~/.local/bin` to `PATH` so `uv tool install`
deployments are visible to GUI-launched apps.

## Config knobs

Edit the scripts if needed:

- `SAVE_INTERVAL`
- `STATE_DIR`
- `MEMPAL_DIR`
- `MEMPAL_VERBOSE`
- `MEMPAL_PYTHON`

Shipped defaults:

- `SAVE_INTERVAL=3`
- fallback wing = `codex_sessions_unscoped`

`MEMPAL_DIR` is additive. It does not replace transcript mining.

## State and logs

Hook runtime state is written to:

```bash
~/.mempalace/hook_state/
```

That includes:

- `hook.log`
- `*_last_save`
- staged transcript temp directories during mining
- parse diagnostics on failure

## Limitations

- Hook config changes require restarting the client session
- `Stop` mining is synchronous by design in this fork, so every checkpoint adds
  a short pause
- This repo is a maintained fork of the current shell-hook path, not a copy of
  upstream `hooks/` on `develop`
