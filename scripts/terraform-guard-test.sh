#!/bin/sh
# Tests scripts/terraform-guard.sh on plans written here, and scripts/terraform.sh
# with a stub terraform and agenix, so it needs no tokens and touches nothing.
# Passes print to stdout and failures to stderr, so scripts/check.sh can stay
# quiet about the passes.
set -eu
cd "$(git rev-parse --show-toplevel)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

ok() { echo "ok - $1"; }
not_ok() {
  echo "not ok - $1" >&2
  failures=$((failures + 1))
}

runner='incus_instance.guest[\"runner\"]'
other='unifi_client.guest[\"plex\"]'
guest='incus_instance.guest[\"photos\"]'
canary='canary-value'

change() {
  printf '{"address":"%s","change":{"actions":%s,"after":{"token":"%s"}}}' "$1" "$2" "$canary"
}
plan() {
  printf '{"format_version":"1.2","resource_changes":[%s]}\n' "$1"
}
quiet_runner="$(change "$runner" '["no-op"]')"

passes() {
  if output="$(printf '%s' "$2" | scripts/terraform-guard.sh 2>&1)"; then
    ok "passes: $1"
  else
    not_ok "passes: $1 (refused: $output)"
  fi
}
refuses() {
  if output="$(printf '%s' "$2" | scripts/terraform-guard.sh 2>&1)"; then
    not_ok "refuses: $1 (passed)"
  elif printf '%s' "$output" | grep -q "$canary"; then
    not_ok "refuses: $1 (printed a value from the plan)"
  elif ! printf '%s' "$output" | grep -q 'desktop'; then
    not_ok "refuses: $1 (doesn't say to use the desktop: $output)"
  else
    ok "refuses: $1"
  fi
}

passes 'no-op on the runner' "$(plan "$quiet_runner")"
passes 'changes only to other resources' "$(plan "$quiet_runner,$(change "$other" '["update"]')")"
passes 'a move of the runner that changes nothing' \
  "$(plan '{"address":"incus_instance.moved","previous_address":"'"$runner"'","change":{"actions":["no-op"]}}')"

for actions in '["create"]' '["update"]' '["delete"]' '["delete","create"]' '["create","delete"]' '["forget"]'; do
  refuses "$actions on the runner" "$(plan "$(change "$runner" "$actions")")"
done
refuses 'a change to the runner beside other changes' \
  "$(plan "$(change "$other" '["update"]'),$(change "$runner" '["update"]')")"
refuses 'a move of the runner that also changes it' \
  "$(plan '{"address":"incus_instance.moved","previous_address":"'"$runner"'","change":{"actions":["update"]}}')"
refuses 'a no-op and a deposed delete on the runner' \
  "$(plan "$quiet_runner,$(change "$runner" '["delete"]')")"

passes 'a new guest' "$(plan "$quiet_runner,$(change "$guest" '["create"]')")"
passes 'an update to another guest' "$(plan "$quiet_runner,$(change "$guest" '["update"]')")"
passes 'a delete outside the guests' "$(plan "$quiet_runner,$(change "$other" '["delete"]')")"
for actions in '["delete"]' '["delete","create"]' '["create","delete"]'; do
  refuses "$actions on another guest" "$(plan "$quiet_runner,$(change "$guest" "$actions")")"
done
refuses 'a move of another guest that deletes it' \
  "$(plan "$quiet_runner,"'{"address":"incus_instance.moved","previous_address":"'"$guest"'","change":{"actions":["delete"]}}')"

refuses 'empty input' ''
refuses 'something that is not JSON' 'not json canary-value'
refuses 'truncated JSON' '{"format_version":"1.2","resource_changes":[{"address":"canary-value"'
refuses 'two documents' "$(plan "$quiet_runner")$(plan "$quiet_runner")"
refuses 'an empty object' '{}'
refuses 'a plan format it does not know' '{"format_version":"2.0","resource_changes":[]}'
refuses 'no format version' '{"resource_changes":[]}'
refuses 'resource changes of the wrong type' '{"format_version":"1.2","resource_changes":"canary-value"}'
refuses 'an entry of the wrong type' '{"format_version":"1.2","resource_changes":["canary-value"]}'
refuses 'a plan that does not list the runner' "$(plan "$(change "$other" '["update"]')")"
refuses 'a plan with no resources' '{"format_version":"1.2","resource_changes":[]}'
refuses 'a runner entry with no actions' "$(plan '{"address":"'"$runner"'","change":{}}')"

plan "$quiet_runner" >"$work/quiet.json"
if scripts/terraform-guard.sh "$work/quiet.json" 2>/dev/null; then
  ok 'reads a file as well as stdin'
else
  not_ok 'reads a file as well as stdin'
fi
if scripts/terraform-guard.sh "$work/missing.json" 2>/dev/null; then
  not_ok 'refuses a file that is not there'
else
  ok 'refuses a file that is not there'
fi

mkdir "$work/empty-path"
shell="$(command -v sh)"
if output="$(PATH="$work/empty-path" "$shell" scripts/terraform-guard.sh "$work/quiet.json" 2>&1)"; then
  not_ok 'refuses with no jq on PATH (passed)'
elif printf '%s' "$output" | grep -q 'no jq on PATH'; then
  ok 'refuses with no jq on PATH'
else
  not_ok "refuses with no jq on PATH (said: $output)"
fi

mkdir "$work/stubs" "$work/secrets"
cat >"$work/stubs/terraform" <<'STUB'
#!/bin/sh
echo "$*" >>"$STUB_LOG"
case "$1" in
  show)
    [ -z "${STUB_SHOW_FAILS:-}" ] || exit 1
    cat "$STUB_PLAN"
    ;;
esac
STUB
cat >"$work/stubs/agenix" <<'STUB'
#!/bin/sh
echo stub-secret
STUB
chmod +x "$work/stubs/terraform" "$work/stubs/agenix"
for name in cloud-token hcloud-token cloudflare-token access-emails unifi-token incus-key; do
  echo stub-secret >"$work/secrets/terraform-$name"
done
plan "$(change "$runner" '["delete","create"]')" >"$work/replace.json"

STUB_LOG="$work/terraform.log"
export STUB_LOG
stubbed() {
  : >"$STUB_LOG"
  PATH="$work/stubs:$PATH" STUB_PLAN="$1" scripts/terraform.sh apply >/dev/null 2>&1
}
stubbed_on_runner() {
  TERRAFORM_SECRETS_DIR="$work/secrets" stubbed "$1"
}
ran() { grep -q "^$1 " "$STUB_LOG"; }
last_word() { sed -n "s/^$1 .* //p" "$STUB_LOG"; }

if (
  unset TERRAFORM_SECRETS_DIR
  stubbed "$work/replace.json"
) && ! ran show && ran apply; then
  ok 'the desktop applies a plan that replaces the runner, with no guard'
else
  not_ok 'the desktop applies a plan that replaces the runner, with no guard'
fi

if stubbed_on_runner "$work/quiet.json" && ran show && ran apply &&
  [ "$(last_word show)" = "$(last_word apply)" ] && [ -n "$(last_word apply)" ]; then
  ok 'the job checks the same file it applies, and applies a plan that passes'
else
  not_ok 'the job checks the same file it applies, and applies a plan that passes'
fi

if ! stubbed_on_runner "$work/replace.json" && ran show && ! ran apply; then
  ok 'the job stops before the apply on a plan that replaces the runner'
else
  not_ok 'the job stops before the apply on a plan that replaces the runner'
fi

if ! STUB_SHOW_FAILS=1 stubbed_on_runner "$work/quiet.json" && ran show && ! ran apply; then
  ok 'the job stops before the apply when terraform show fails'
else
  not_ok 'the job stops before the apply when terraform show fails'
fi

: >"$STUB_LOG"
if PATH="$work/stubs:$PATH" TERRAFORM_SECRETS_DIR="$work/secrets" STUB_PLAN="$work/replace.json" \
  scripts/terraform.sh >/dev/null 2>&1 && ! ran show && ! ran apply; then
  ok 'a plan on its own runs no guard and no apply'
else
  not_ok 'a plan on its own runs no guard and no apply'
fi

if [ "$failures" -gt 0 ]; then
  echo "$failures failed" >&2
  exit 1
fi
