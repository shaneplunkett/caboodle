#!/usr/bin/env bash
# SessionStart hook shared by Codex and Claude Code.
#
# rbw prompts only in a terminal, so MCP servers and CLI wrappers started by an
# agent fail while it's locked. Tell the agent up front so it can flag it,
# instead of finding out from a missing MCP server mid-task.

set -euo pipefail

cat >/dev/null

# Agents can start without XDG_RUNTIME_DIR, which rbw needs to find its agent.
if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ]; then
  export XDG_RUNTIME_DIR="/run/user/$(id -u)"
fi

rbw unlocked >/dev/null 2>&1 && exit 0

jq -n '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: "rbw (Bitwarden) is locked. MCP servers and CLIs that pull API keys from it (context7, tvly, bb, langsmith, td, unifi) will fail until it is unlocked. Mention this to Shane early, and suggest she runs `rbw unlock` in a terminal."
  }
}'
