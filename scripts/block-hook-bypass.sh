#!/bin/sh
# PreToolUse hook on shell commands, for Claude Code and Codex. Blocks the
# ways an agent can skip the git hooks, which run scripts/check.sh on every
# commit: --no-verify (and git's abbreviations of it), commit's -n, SKIP=
# for pre-commit, pointing core.hooksPath elsewhere, and removing the hooks.
#
# It reads the command out of the hook JSON with sed rather than jq, so it
# stays fast and needs nothing beyond a POSIX shell. A flag only counts as
# commit's -n when it follows `commit` in the same command and isn't quoted,
# so `jq -n` on the next line or a message mentioning -n gets through. Other
# text can still match, like a quoted --no-verify. That's rare, and the error
# says what to do.

input="$(cat)"

command="$(printf '%s' "$input" | sed -nE 's/.*"(command|cmd)" *: *"(([^"\\]|\\.)*)".*/\2/p')"
[ -n "$command" ] || command="$input"

# Undo the JSON escapes the checks care about. An escaped line continuation
# joins its lines, and any other newline ends a command, as it does in the
# shell.
command="$(printf '%s' "$command" | sed -E 's/\\\\\\n/ /g; s/\\\\/%/g; s/\\n/;/g; s/\\t/ /g; s/\\"/"/g')"

commit_args="$(
  printf '%s\n' "$command" |
    grep -Eo '(^|[;&|[:space:](])git([[:space:]][^;&|]*)?[[:space:]]commit([[:space:]][^;&|]*)?' |
    while IFS= read -r commit; do printf ' %s' "${commit#*[[:space:]]commit}"; done |
    sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g"
)"

matches() {
  printf '%s' "$command" | grep -Eq "$@"
}

if matches -e '--no-veri' ||
  printf '%s' "$commit_args" | grep -Eq '(^|[[:space:]])-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' ||
  matches -i -e 'core\.hookspath([[:space:]]*=|[[:space:]]+[^-;&|[:space:]])' ||
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
