#!/bin/sh
# PreToolUse hook on shell commands, for Claude Code and Codex. Builds and
# evaluations happen on Shane's desktop now, and only through
# scripts/quietly.sh, which serialises them and runs them at idle priority
# so they never fight what she's doing on the machine. This blocks the bare
# forms: colmena, nix build, nix-build, nixos-rebuild, darwin-rebuild, the nh
# switch commands and the nrs alias.
#
# It reads the command out of the hook JSON the same way
# block-hook-bypass.sh does, with sed rather than jq, to stay fast.

input="$(cat)"

command="$(printf '%s' "$input" | sed -nE 's/.*"(command|cmd)" *: *"(([^"\\]|\\.)*)".*/\2/p')"
[ -n "$command" ] || command="$input"
command="$(printf '%s' "$command" | sed -E 's/\\\\\\n/ /g; s/\\\\/%/g; s/\\n/;/g; s/\\t/ /g; s/\\"/"/g')"

case "$command" in
  *quietly.sh*) exit 0 ;;
esac

if printf '%s\n' "$command" | grep -Eq \
  -e '(^|[;&|[:space:](`$])(colmena|nix-build|nixos-rebuild|darwin-rebuild|nrs)([[:space:]]|$)' \
  -e '(^|[;&|[:space:](`$])nix[[:space:]]+build([[:space:]]|$)' \
  -e '(^|[;&|[:space:](`$])nh[[:space:]]+(os|darwin|home)[[:space:]]'; then
  {
    echo "Blocked: builds and evaluations run here, on Shane's desktop, and only"
    echo "through scripts/quietly.sh, which queues them behind each other and runs"
    echo "them at idle priority so they never get in her way. Prefix the command:"
    echo "  scripts/quietly.sh colmena build --on <host>"
    echo "  scripts/quietly.sh nix build .#hydraJobs.<host>"
    echo "If the match is only text inside a commit message, write the message to"
    echo "a file and commit with -F."
  } >&2
  exit 2
fi
