#!/bin/sh
# Tests scripts/report-deploy-failure.sh with a curl that only writes down what it
# was given, so nothing leaves this machine. The apply case has to match the
# fixture the bridge's own tests read, which is what keeps the two sides agreeing
# on the payload. Passes print to stdout and failures to stderr, so
# scripts/check.sh can stay quiet about the passes.
set -eu

root="$(cd "$(dirname "$0")/.." && pwd)"
script="$root/scripts/report-deploy-failure.sh"
fixture="$root/pkgs/linear-bridge/testdata/deploy-failed.json"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

ok() { echo "ok - $1"; }
not_ok() {
  echo "not ok - $1" >&2
  failures=$((failures + 1))
}

mkdir -p "$work/bin"
cat >"$work/bin/curl" <<SHIM
#!/bin/sh
printf '%s\n' "\$@" >"$work/curl-args"
cat >"$work/curl-body"
exit "\${FAKE_CURL_EXIT:-0}"
SHIM
chmod +x "$work/bin/curl"

report() {
  rm -f "$work/curl-args" "$work/curl-body"
  PATH="$work/bin:$PATH" \
    LINEAR_BRIDGE_URL=http://bridge.test/alerts \
    RUNNER_TEMP="$work/temp" \
    GITHUB_SERVER_URL=https://github.com \
    GITHUB_REPOSITORY=shaneplunkett/caboodle \
    GITHUB_SHA=cd0a11f3aaaabbbbccccddddeeeeffff00001111 \
    GITHUB_RUN_ID=41635043424 \
    STEPS="$1" \
    "$script"
}

fresh_logs() {
  rm -rf "$work/temp"
  mkdir -p "$work/temp"
}

field() {
  jq -r ".alerts[0].$1" "$work/curl-body"
}

check() {
  if [ "$2" = "$3" ]; then
    ok "$1"
  else
    not_ok "$1: got '$2', wanted '$3'"
  fi
}

failed_steps='{"build":{"outcome":"success"},"apply":{"outcome":"failure"}}'

fresh_logs
cat >"$work/temp/apply.log" <<'LOG'
ERROR Failed to deploy to monitoring - Last 20 lines of logs:
ERROR   stderr) warning: the following units failed: linear-bridge.service
ERROR  failure) Activation unit colmena-activate-e5ba on host monitoring failed with result exit-code, exit status 4
ERROR Failed to complete requested operation - Last 1 lines of logs:
LOG
report "$failed_steps"
got="$(jq -S 'del(.alerts[0].startsAt)' "$work/curl-body")"
want="$(jq -S 'del(.alerts[0].startsAt)' "$fixture")"
check "a failed apply posts the payload the bridge's tests read" "$got" "$want"
check "it posts to the bridge's URL" "$(tail -n 1 "$work/curl-args")" http://bridge.test/alerts
if field startsAt | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'; then
  ok "startsAt is an RFC 3339 time"
else
  not_ok "startsAt is $(field startsAt)"
fi
check "it never ends, so only Shane closes it" "$(field endsAt)" null
if grep -qx -- --retry-connrefused "$work/curl-args"; then
  ok "it retries while the bridge restarts"
else
  not_ok "curl has no --retry-connrefused"
fi
if grep -qx -- --fail "$work/curl-args"; then
  ok "a refused post fails the step"
else
  not_ok "curl has no --fail"
fi

fresh_logs
cat >"$work/temp/apply.log" <<'LOG'
ERROR Failed to deploy to plex - Last 20 lines of logs:
ERROR Failed to deploy to monitoring - Last 20 lines of logs:
ERROR Failed to deploy to plex - Last 20 lines of logs:
LOG
report "$failed_steps"
check "every host colmena names is on the alert, once" "$(field 'labels.host')" "monitoring, plex"

fresh_logs
cat >"$work/temp/build.log" <<'LOG'
error: builder for 'x' failed with exit code 1
build-linux-hosts: these hosts didn't build: pve rss
LOG
report '{"build":{"outcome":"failure"}}'
check "a failed build names its hosts" "$(field 'labels.host')" "pve, rss"
case "$(field 'annotations.description')" in
  *"builder for"*) ok "a failed build carries its last lines" ;;
  *) not_ok "description is $(field 'annotations.description')" ;;
esac

fresh_logs
echo "error: cannot add path" >"$work/temp/push.log"
report '{"build":{"outcome":"success"},"push":{"outcome":"failure"}}'
check "a failure that names no host says runner" "$(field 'labels.host')" runner

fresh_logs
report '{"terraform":{"outcome":"failure"}}'
check "a step with no log has no description" "$(field 'annotations.description')" ""
case "$(field 'annotations.condition')" in
  *"step \`terraform\`"*) ok "and still names the step" ;;
  *) not_ok "condition is $(field 'annotations.condition')" ;;
esac

fresh_logs
echo "tail of push" >"$work/temp/push.log"
echo "ERROR Failed to deploy to rss - Last 20 lines of logs:" >"$work/temp/apply.log"
report '{"push":{"outcome":"failure"},"apply":{"outcome":"failure"}}'
case "$(field 'annotations.condition')" in
  *"step \`push, apply\`"*) ok "two failed steps are both named" ;;
  *) not_ok "condition is $(field 'annotations.condition')" ;;
esac
check "and a host from either counts" "$(field 'labels.host')" rss

fresh_logs
report '{"build":{"outcome":"success"}}'
check "a failure in a step with no id still files" "$(field 'labels.host')" runner

fresh_logs
for n in $(seq 40); do echo "line $n"; done >"$work/temp/apply.log"
printf '```\n\033[31mred\033[0m\n' >>"$work/temp/apply.log"
printf '%0500d\n' 0 >>"$work/temp/apply.log"
report "$failed_steps"
description="$(field 'annotations.description')"
case "$description" in
  *"line 20"*) not_ok "line 20 of 43 is still there" ;;
  *) ok "only the last lines are kept" ;;
esac
if [ "$(printf '%s\n' "$description" | grep -c '```')" = 2 ]; then
  ok "a fence in the log can't close the code block"
else
  not_ok "fences in: $description"
fi
if printf '%s' "$description" | grep -q "$(printf '\033')"; then
  not_ok "colour codes reached the issue"
else
  ok "colour codes are stripped"
fi
if printf '%s\n' "$description" | grep -Eq '.{241}'; then
  not_ok "a very long line reached the issue whole"
else
  ok "very long lines are cut"
fi

fresh_logs
if FAKE_CURL_EXIT=22 report "$failed_steps" 2>/dev/null; then
  not_ok "a post that fails should fail the step"
else
  ok "a post that fails fails the step"
fi

fresh_logs
if PATH="$work/bin:$PATH" RUNNER_TEMP="$work/temp" STEPS='{}' \
  GITHUB_SERVER_URL=x GITHUB_REPOSITORY=x GITHUB_SHA=x GITHUB_RUN_ID=1 \
  "$script" 2>/dev/null; then
  not_ok "a runner with no bridge URL should fail"
else
  ok "a runner with no bridge URL fails the step"
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures failed" >&2
  exit 1
fi
