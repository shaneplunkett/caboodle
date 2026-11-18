# Codex

There are three Codex homes, all signed in to the same account.

- `~/.codex` is Vex's: the managed context, skills, hooks and shared MCP
  servers, plus `vex boot` on `SessionStart`.
- `~/.codex-code` is Code Girly's. She has her own writable home and session
  history, and the shared hooks without `vex boot`.
- `~/.codex-bare` is stock Codex, with none of the managed context, skills,
  hooks or MCP servers. It's for pull request reviews through the Codex
  plugin for Claude Code (`CODEX_HOME`) and the Codex Bare provider. It pins a
  model and turns off the remote plugin and app sync, which would otherwise
  fill the home the first time the app server starts.

`vex.ai.codex` publishes the three directory names for other modules, such
as vex-code.

## Gotchas

- Codex rewrites `auth.json` in place when it refreshes the token, so the
  other two homes symlink `~/.codex/auth.json` instead of copying it. A copy
  would drift onto a stale token.
- `config.toml` is merged on every switch rather than linked, so Codex can
  still write its runtime fields into it.
- Codex runs a hook only once it's been approved, and the approval hash covers
  the hook's declaration, its command included. A `/nix/store` command would
  lose its approval on every rebuild that moved it. The app server that T3
  and the Codex app talk to skips an unapproved hook without saying so. So
  each hook's command is a stable link under `~/.local/share/codex-hooks`.
  Editing a script keeps its approval. Adding a hook, changing a timeout or
  matcher, or inserting one ahead of others in the same event needs approving
  again, so open `codex` in a terminal for each home after a switch like that.
- `features.multi_agent_v2` uses the `agents` tool namespace and shows the
  spawn metadata, because GPT-5.6 Sol's reserved `collaboration.spawn_agent`
  schema hides custom agent and model routing. Drop it once
  openai/codex#31814 and #32031 are fixed.
