# Codex

There are three Codex homes, all signed in to the same account.

- `~/.codex` is Vex's: the managed context, skills, hooks and shared MCP
  servers, plus Vex's session context on `SessionStart`.
- `~/.codex-code` is Code Girly's. She has her own writable home and session
  history, and the shared hooks without Vex's session context.
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
- `features.multi_agent_v2` uses the `agents` tool namespace and shows the
  spawn metadata, because GPT-5.6 Sol's reserved `collaboration.spawn_agent`
  schema hides custom agent and model routing. Drop it once
  openai/codex#31814 and #32031 are fixed.
