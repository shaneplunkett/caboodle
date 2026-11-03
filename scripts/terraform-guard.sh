#!/bin/sh
# Says whether the deploy job may apply a Terraform plan. Terraform manages the
# container the job runs in, so an apply that changes it can kill the job
# halfway and leave the state lock held. Reads `terraform show -json` from a
# file or stdin, exits 0 if the plan leaves the runner's container alone, and 1
# otherwise.
#
#   scripts/terraform-guard.sh plan.json
#
# Anything it can't read counts as a refusal, and so does a plan that doesn't
# list the container, since a real plan lists it as a no-op. jq's errors can
# quote the input, and a plan holds secrets, so they go nowhere. It only ever
# prints a resource's address and actions.
set -eu

runner='incus_instance.guest["runner"]'
desktop='Apply it from the desktop with scripts/terraform.sh apply while the runner is idle.'

if ! command -v jq >/dev/null 2>&1; then
  echo "terraform-guard: no jq on PATH, so not applying. Run scripts/deploy.sh runner from the desktop." >&2
  exit 1
fi

filter="$(
  cat <<'JQ'
  if length != 1 then error("want one document") else .[0] end
  | if (.format_version | startswith("1.")) and (.resource_changes | type == "array")
    then . else error("unexpected shape") end
  | [.resource_changes[] | select(.address == $runner or .previous_address == $runner)]
  | if length == 0 then error("runner not listed") else . end
  | .[]
  | select(.change.actions != ["no-op"])
  | "\(.address) \(.change.actions | join("+"))"
JQ
)"

if ! refused="$(jq -rs --arg runner "$runner" "$filter" "$@" 2>/dev/null)"; then
  echo "terraform-guard: can't tell what this plan does to $runner, so not applying. $desktop" >&2
  exit 1
fi

if [ -n "$refused" ]; then
  echo "terraform-guard: this plan changes the container the job runs in, so not applying:" >&2
  echo "$refused" >&2
  echo "$desktop" >&2
  exit 1
fi
