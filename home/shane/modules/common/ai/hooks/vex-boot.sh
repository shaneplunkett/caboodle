#!/usr/bin/env bash
# SessionStart hook for Claude Code and Vex's Codex.
#
# Runs `vex boot` and hands its output to the agent, so a session opens with
# Shane's memory context (Melbourne time, today's state, yesterday's session,
# open follow-ups) instead of the agent having to remember to fetch it.

set -euo pipefail

cat >/dev/null

# Agents can start without XDG_RUNTIME_DIR, which the vex wrapper's rbw needs.
if [ -z "${XDG_RUNTIME_DIR:-}" ] && [ -d "/run/user/$(id -u)" ]; then
  XDG_RUNTIME_DIR="/run/user/$(id -u)"
  export XDG_RUNTIME_DIR
fi

if boot=$(vex boot 2>&1); then
  context="Output of \`vex boot\`, run at session start:

$boot"
else
  context="\`vex boot\` failed at session start, so this session has no memory context yet. Run it yourself before answering Shane, and tell her if it fails again.

$boot"
fi

jq -n --arg ctx "$context" '{
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $ctx
  }
}'
