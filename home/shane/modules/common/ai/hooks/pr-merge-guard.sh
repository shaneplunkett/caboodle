#!/usr/bin/env bash
# PreToolUse guard shared by Codex and Claude Code.
#
# Private repos on a free plan get no branch protection, so nothing on GitHub
# stops a merge while CI is still running. This blocks `gh pr merge` until every
# check on the PR's head commit has passed. Zero checks counts as "not yet" when
# the repo has workflows, since a run takes a few seconds to register after a push.

set -euo pipefail

mode="${1:-codex}"
payload="$(cat || true)"

command=$(
  jq -r '
    if (.tool_input.cmd? | type) == "string" then
      .tool_input.cmd
    elif (.tool_input.command? | type) == "string" then
      .tool_input.command
    elif (.tool_input | type) == "string" then
      .tool_input
    else
      ""
    end
  ' <<<"$payload" 2>/dev/null || true
)

[ -n "$command" ] || exit 0

flat_command="$(printf '%s' "$command" | tr '\n' ' ')"

merge_args="$(grep -Eo '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]][^;&|]*)?' <<<"$flat_command" | head -n 1 || true)"
[ -n "$merge_args" ] || exit 0
merge_args="$(sed -E 's/^.*gh[[:space:]]+pr[[:space:]]+merge//' <<<"$merge_args")"

# Run gh where the merge would run: Codex's workdir, else a `cd DIR` earlier in the command.
workdir="$(jq -r '.tool_input.workdir? // empty' <<<"$payload" 2>/dev/null || true)"
cd_dir="$(grep -Eo '(^|[;&|[:space:]])cd[[:space:]]+[^;&|[:space:]]+' <<<"${flat_command%%gh pr merge*}" | tail -n 1 | sed -E 's/^.*cd[[:space:]]+//' || true)"
[ -n "$cd_dir" ] && workdir="${cd_dir/#\~/$HOME}"
[ -n "$workdir" ] && [ -d "$workdir" ] && cd "$workdir"

pr=""
repo=""
read -r -a words <<<"$merge_args"
i=0
while [ "$i" -lt "${#words[@]}" ]; do
  word="${words[$i]}"
  case "$word" in
    -R | --repo)
      i=$((i + 1))
      repo="${words[$i]:-}"
      ;;
    --repo=*) repo="${word#--repo=}" ;;
    -b | --body | -F | --body-file | -t | --subject | --match-head-commit | -A | --author-email)
      i=$((i + 1))
      ;;
    -*) ;;
    *) [ -z "$pr" ] && pr="$word" ;;
  esac
  i=$((i + 1))
done

# gh exits non-zero while checks are pending or failing, so keep stdout either way.
errfile="$(mktemp)"
trap 'rm -f "$errfile"' EXIT
checks="$(gh pr checks ${pr:+"$pr"} ${repo:+--repo "$repo"} --json name,bucket 2>"$errfile")" || true
if [ -z "$checks" ]; then
  # gh can't see the PR (offline, not a repo, bad ref): let the merge itself report that.
  grep -q 'no checks reported' "$errfile" || exit 0
  api_repo="{owner}/{repo}"
  [ -n "$repo" ] && api_repo="$repo"
  workflows="$(gh api "repos/$api_repo/actions/workflows" --jq '.total_count' 2>/dev/null || echo 0)"
  [ "$workflows" -gt 0 ] 2>/dev/null || exit 0
  checks="[]"
fi

label="${pr:-the PR for this branch}"
pending="$(jq -r '[.[] | select(.bucket == "pending") | .name] | join(", ")' <<<"$checks")"
failed="$(jq -r '[.[] | select(.bucket == "fail" or .bucket == "cancel") | .name] | join(", ")' <<<"$checks")"
total="$(jq 'length' <<<"$checks")"

reason=""
if [ -n "$failed" ]; then
  reason="Blocked gh pr merge: CI failed on $label ($failed). Fix the failures and push before merging."
elif [ -n "$pending" ]; then
  reason="Blocked gh pr merge: CI is still running on $label ($pending). Wait with \`gh pr checks ${pr:-} --watch\`, then merge once every check passes."
elif [ "$total" -eq 0 ]; then
  reason="Blocked gh pr merge: this repo has CI workflows but no checks have reported on $label yet. A run takes a few seconds to register after a push. Wait with \`gh pr checks ${pr:-} --watch\`, then merge."
fi

[ -n "$reason" ] || exit 0

case "$mode" in
  claude)
    jq -n --arg reason "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      },
      systemMessage: $reason
    }'
    ;;
  codex)
    jq -n --arg reason "$reason" '{
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        additionalContext: $reason
      }
    }'
    ;;
  *)
    printf '%s\n' "$reason" >&2
    exit 2
    ;;
esac
