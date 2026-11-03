#!/bin/sh
# Tests the runners' job-started hook. A copy of bash called Runner.Worker stands in
# for the worker and runs the hook the way the runner does, then the test looks at
# whether the hook signalled it. Pass a path to test a built hook instead of the
# source: job-started-test.sh result/bin/job-started.sh
set -eu

hook=${1:-$(dirname "$0")/job-started.sh}
repository=shaneplunkett/caboodle
ref=refs/heads/main

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cp "$(command -v bash)" "$dir/Runner.Worker"
cp "$(command -v bash)" "$dir/Some.Parent"

export HOOK="$hook" SIGNALLED="$dir/signalled" RAN="$dir/ran" OUTPUT="$dir/output"

# Takes the signal the way the real worker does: it records it and kills the hook.
cat >"$dir/takes-signal" <<'EOF'
trap 'echo TERM >"$SIGNALLED"; kill "$hook" 2>/dev/null; exit 0' TERM
bash -euo pipefail "$HOOK" 1 >"$OUTPUT" 2>&1 &
hook=$!
wait "$hook" && echo ran >"$RAN"
EOF

cat >"$dir/process-between" <<'EOF'
trap 'echo TERM >"$SIGNALLED"; exit 0' TERM
bash -c 'bash -euo pipefail "$HOOK" 1 >"$OUTPUT" 2>&1; :' &
wait $!
EOF

cat >"$dir/ignores-signal" <<'EOF'
trap "" TERM
bash -euo pipefail "$HOOK" 1 >"$OUTPUT" 2>&1 &
wait $!
echo ran >"$RAN"
EOF

failed=0

fail() {
  echo "FAIL: $1" >&2
  failed=1
}

reset() {
  rm -f "$SIGNALLED" "$RAN" "$OUTPUT"
}

allows() {
  name=$1
  reset
  "$dir/Runner.Worker" "$dir/takes-signal" || true
  if [ -e "$SIGNALLED" ]; then
    fail "$name: signalled the worker"
  elif [ ! -e "$RAN" ]; then
    fail "$name: hook failed: $(cat "$OUTPUT")"
  fi
}

refuses() {
  name=$1
  reset
  "$dir/Runner.Worker" "$dir/takes-signal" || true
  if [ ! -e "$SIGNALLED" ]; then
    fail "$name: left the worker running"
  elif ! grep -q '^::error title=Runner guard::Job refused\. ' "$OUTPUT"; then
    fail "$name: no reason in the log: $(cat "$OUTPUT")"
  fi
}

set_both() {
  export GITHUB_REPOSITORY="$1" GITHUB_REF="$2"
}

set_both "$repository" "$ref"
allows "caboodle on main"

set_both "$repository" "$ref"
unset GITHUB_REPOSITORY
refuses "missing repository"
set_both "" "$ref"
refuses "empty repository"
set_both "someone/caboodle" "$ref"
refuses "another owner's repository"
set_both "shaneplunkett/vex-brain" "$ref"
refuses "another repository"
set_both "$repository-evil" "$ref"
refuses "repository with trailing garbage"
set_both "$repository " "$ref"
refuses "repository with a trailing space"
set_both "ShanePlunkett/Caboodle" "$ref"
refuses "repository in another case"

set_both "$repository" "$ref"
unset GITHUB_REF
refuses "missing ref"
set_both "$repository" ""
refuses "empty ref"
set_both "$repository" "refs/heads/some-branch"
refuses "another branch"
set_both "$repository" "main"
refuses "bare branch name"
set_both "$repository" "refs/tags/main"
refuses "tag called main"
set_both "$repository" "refs/pull/1/merge"
refuses "pull request merge ref"
set_both "$repository" "refs/heads/main-2"
refuses "branch starting with main"
set_both "$repository" "$ref "
refuses "ref with a trailing space"
set_both "$repository" "$ref
"
refuses "ref with a trailing newline"
set_both "$repository" "refs/heads/refs/heads/main"
refuses "branch called refs/heads/main"
set_both "$repository" "refs/heads/*"
refuses "ref that looks like a pattern"

# A newline can't end the line the error sits on, or a value could start its own
# workflow command.
set_both "$repository" "x
::add-mask::y"
reset
"$dir/Runner.Worker" "$dir/takes-signal" || true
if grep -q '^::add-mask::' "$OUTPUT"; then
  fail "a value started its own workflow command"
fi

set_both "$repository" "refs/heads/some-branch"

# Something between the worker and the hook doesn't take the signal in its place.
reset
"$dir/Runner.Worker" "$dir/process-between" || true
if [ ! -e "$SIGNALLED" ]; then
  fail "signalled the process in between, not the worker"
fi

# With no worker above it, the hook signals its parent.
reset
"$dir/Some.Parent" "$dir/takes-signal" || true
if [ ! -e "$SIGNALLED" ]; then
  fail "left its parent running with no worker to find"
fi

# A worker that ignores SIGTERM gets SIGKILL when the grace period runs out. The
# subshell keeps the shell's "Killed" line out of the gate's output.
reset
(
  set +e
  "$dir/Runner.Worker" "$dir/ignores-signal"
  echo "$?" >"$dir/status"
) 2>/dev/null
status=$(cat "$dir/status")
if [ "$status" -ne 137 ] || [ -e "$RAN" ]; then
  fail "worker that ignores SIGTERM survived, status $status"
fi

if [ "$failed" -ne 0 ]; then
  exit 1
fi
echo "job-started hook: every case passed"
