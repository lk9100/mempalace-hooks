# Upstream Notes

This repo is a small maintenance fork of the upstream MemPalace shell hooks.
Its reference upstream is:

- repo: [`MemPalace/mempalace`](https://github.com/MemPalace/mempalace)
- hook shape: [`develop/hooks`](https://github.com/MemPalace/mempalace/tree/develop/hooks)

## What To Treat As Forked Behavior

When comparing this repo to upstream, preserve these local decisions unless you
intentionally want to change behavior:

- derive the target wing from transcript `cwd`
- only use a derived project wing when that wing already exists
- fall back to `codex_sessions_unscoped` for unscoped or ambiguous sessions
- mine only the active transcript during hook execution
- count Codex `event_msg` / `user_message` entries as human messages
- keep compaction-time mining synchronous

## Safe Update Workflow

If you want to pull in upstream hook changes later:

1. Review the current upstream files under `develop/hooks`.
2. Diff upstream behavior against `hooks/` in this repo.
3. Keep the forked behaviors above unless you have a reason to change them.
4. Re-test both entrypoint scripts with:

```bash
bash -n hooks/mempal_save_hook.sh hooks/mempal_precompact_hook.sh hooks/mempal_hook_common.sh
```

5. Re-read `README.md` and update it if behavior or install assumptions
   changed.

## Scope Of This Repo

This repo is deliberately self-contained for the shell-hook use case:

- it contains the standalone shell hooks
- it documents the local behavior differences from upstream
- it does not try to vendor the full MemPalace project

If you need broader MemPalace features or want to follow upstream development
outside the shell-hook path, start from the upstream repo instead of this fork.
