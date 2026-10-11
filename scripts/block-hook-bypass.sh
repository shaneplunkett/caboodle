#!/bin/sh
# PreToolUse hook on shell commands, for Claude Code and Codex. Blocks the
# ways an agent can skip the git hooks, which run scripts/check.sh on every
# commit: --no-verify (and git's abbreviations of it), commit's -n, SKIP=
# for pre-commit, pointing core.hooksPath elsewhere, and removing the hooks.
#
# It greps the raw hook JSON, so it stays fast and needs nothing on PATH.
# The cost is that it can't tell a flag from the same text inside a quoted
# message. That's rare, and the error says what to do.

input="$(cat)"

matches() {
  printf '%s' "$input" | grep -Eq "$@"
}

if matches -e '--no-veri' ||
  matches -e 'git[^|;&]* commit[^|;&]* -[a-zA-Z]*n[a-zA-Z]*([^a-zA-Z]|$)' ||
  matches -i -e 'core\.hookspath' ||
  matches -e '(^|[^A-Za-z0-9_])SKIP=' ||
  matches -e 'pre-commit +uninstall' ||
  matches -e '\.git/hooks'; then
  {
    echo "Blocked: this command skips the git hooks, which run scripts/check.sh on"
    echo "every commit, so unchecked code could land. Fix what the check reports and"
    echo "commit normally. If the hook itself is wrong, say so and propose a change"
    echo "to .pre-commit-config.yaml. Don't look for another way round it."
    echo "If the match is only text inside a commit message, write the message to"
    echo "a file and commit with -F."
  } >&2
  exit 2
fi
