# shellcheck shell=bash
# Refuses every job on this runner unless it comes from caboodle's main. It runs
# as the runner's job-started hook, the first thing in a job.
#
# Exiting non-zero wouldn't be enough. A failed hook fails the job, but the runner
# still walks the job's steps, and a step with `if: always()` runs anyway, with the
# runner's keys. So a refused job stops its Runner.Worker. On SIGTERM the worker
# skips every step left, uploads the log and reports the job failed. If it's still
# there after the grace period, SIGKILL ends the job with nothing left to run it.
#
# The worker kills this script as part of that shutdown, so nothing here gets past
# the wait unless the worker has ignored SIGTERM.
#
# A workflow can't reach these variables: the runner gives a hook an empty step
# environment, then sets GITHUB_* from the job's github context. The argument is
# for the test, since the runner never passes one.
repository=shaneplunkett/caboodle
ref=refs/heads/main
grace=${1:-30}

if [ "${GITHUB_REPOSITORY:-}" = "$repository" ] && [ "${GITHUB_REF:-}" = "$ref" ]; then
  echo "This job is from $repository on $ref, so it can run here."
  exit 0
fi

printf '::error title=Runner guard::Job refused. This runner only takes jobs from %s on %s. This one is from %q on %q, so it stops here and none of its steps run.\n' \
  "$repository" "$ref" "${GITHUB_REPOSITORY:-}" "${GITHUB_REF:-}"

# macOS keeps ps in /bin, which isn't on the job's PATH.
PATH=$PATH:/bin

# The worker starts this script directly, so it's normally the parent. Walking up
# means a process the runner adds in between can't take the signal in its place.
# If the walk finds nothing, the parent is the best guess left, and a failed ps has
# to land here too rather than end the script before the signal.
worker=$PPID
process=$PPID
while [ "$process" -gt 1 ] 2>/dev/null; do
  name=$(ps -o comm= -p "$process") || break
  if [ "${name##*/}" = Runner.Worker ]; then
    worker=$process
    break
  fi
  process=$(ps -o ppid= -p "$process") || break
  process=${process//[[:space:]]/}
done

trap 'exit 1' INT TERM
kill -TERM "$worker" || true

# Nothing holds the step's output open here, or the worker would wait on a sleep
# that outlives this script.
sleep "$grace" >/dev/null 2>&1 &
wait "$!" || true

kill -KILL "$worker" || true
exit 1
