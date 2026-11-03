#!/bin/sh
# Files a failed job on the runner as a Linear issue, by posting one alert to the
# bridge on the monitoring host in Alertmanager's webhook shape. deploy.yml runs
# this when a step fails. If it can't get through, the red cross and GitHub's email
# are still there, so its own failure only turns this step red too.
#
# STEPS is the job's steps context as JSON, which says which steps failed. Each of
# them keeps its output in $RUNNER_TEMP/<step id>.log, so the alert can carry the
# last lines and name the hosts. A failure that names no host says runner.
#
# The fingerprint is the run's id, so re-running a failed job files no twin while
# the issue is open. There's no endsAt and nothing ever posts a resolve, so the
# issue stays open until Shane closes it.
#
#   STEPS='{"apply":{"outcome":"failure"}}' scripts/report-deploy-failure.sh
set -eu

bridge="${LINEAR_BRIDGE_URL:?the runner sets this; scripts/deploy.sh runner from the desktop gives it the URL}"
last_lines=20
longest_line=240

failed="$(printf '%s' "$STEPS" | jq -r '[to_entries[] | select(.value.outcome == "failure") | .key] | join(" ")')"

set --
for step in $failed; do
  if [ -r "$RUNNER_TEMP/$step.log" ]; then
    set -- "$@" "$RUNNER_TEMP/$step.log"
  fi
done

hosts="$(
  cat /dev/null "$@" |
    sed -n \
      -e "s/^build-linux-hosts: these hosts didn't build: *//p" \
      -e 's/.*Failed to deploy to \([^ ]*\) .*/\1/p' |
    tr -s ' ' '\n' |
    sort -u |
    paste -s -d , - |
    sed 's/,/, /g'
)"

tail_of_log=""
read_step=""
if [ $# -gt 0 ]; then
  read_step="$(basename "$1" .log)"
  tail_of_log="$(
    tail -n "$last_lines" "$1" |
      sed -e 's/\x1b\[[0-9;]*[A-Za-z]//g' -e "s/\`\`\`/'''/g" |
      cut -c "1-$longest_line"
  )"
fi

repo_url="$GITHUB_SERVER_URL/$GITHUB_REPOSITORY"

payload="$(
  jq -n \
    --arg short "$(printf '%.7s' "$GITHUB_SHA")" \
    --arg commit "$repo_url/commit/$GITHUB_SHA" \
    --arg run "$repo_url/actions/runs/$GITHUB_RUN_ID" \
    --arg run_id "$GITHUB_RUN_ID" \
    --arg repo "$GITHUB_REPOSITORY" \
    --arg steps "$(printf '%s' "${failed:-unknown}" | sed 's/ /, /g')" \
    --arg host "${hosts:-runner}" \
    --arg read_step "$read_step" \
    --arg tail "$tail_of_log" \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      version: "4",
      status: "firing",
      receiver: "deploy",
      notification_reason: "deploy job failed",
      alerts: [{
        status: "firing",
        labels: {alertname: "DeployFailed", severity: "critical", host: $host},
        annotations: {
          summary: "Deploy of \($short) failed",
          condition: "Commit [\($short)](\($commit)) failed to deploy, in step `\($steps)`, on `\($host)`. [Read the run](\($run)).",
          description: (if $tail == "" then "" else "Last lines of the \($read_step) step:\n\n```\n\($tail)\n```" end),
          check: "gh run view \($run_id) --repo \($repo) --log-failed"
        },
        startsAt: $now,
        fingerprint: "deploy-\($run_id)"
      }]
    }'
)"

printf '%s' "$payload" |
  curl --fail --silent --show-error \
    --max-time 60 --retry 5 --retry-delay 10 --retry-connrefused \
    --header 'Content-Type: application/json' \
    --data-binary @- \
    "$bridge"
