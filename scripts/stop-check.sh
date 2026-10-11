#!/bin/sh
# Stop hook for Claude Code and Codex: runs scripts/check.sh before an agent
# says it's done. Exit 2 sends the errors back, so the agent keeps working.
set -u
export NO_COLOR=1

root="$(git rev-parse --show-toplevel)"
cd "$root" || exit 1

# Codex requires JSON on a successful Stop; Claude Code accepts the same
# neutral response.
allow_stop() {
  printf '%s\n' '{"continue":true}'
  exit 0
}

# Both tools set stop_hook_active once a Stop hook has already sent the
# agent back. Let it stop this time, so a failure it can't fix can't loop.
if grep -q '"stop_hook_active": *true'; then
  allow_stop
fi

# Fingerprint the working tree, tracked and untracked files alike, by
# building a git tree in a throwaway index. If nothing has changed since
# the last pass, skip the check so chat-only turns stay fast.
tmp_index="$(mktemp)"
cp "$(git rev-parse --git-path index)" "$tmp_index" 2>/dev/null || rm -f "$tmp_index"
tree="$(GIT_INDEX_FILE="$tmp_index" git add -A && GIT_INDEX_FILE="$tmp_index" git write-tree)"
rm -f "$tmp_index"

stamp="$(git rev-parse --git-path stop-check-passed)"
if [ -n "$tree" ] && [ "$(cat "$stamp" 2>/dev/null)" = "$tree" ]; then
  allow_stop
fi

if output="$(scripts/in-dev-shell.sh scripts/check.sh 2>&1)"; then
  echo "$tree" >"$stamp"
  allow_stop
fi

{
  echo "scripts/check.sh failed. Fix these before finishing:"
  echo "$output" | tail -n 40
} >&2
exit 2
