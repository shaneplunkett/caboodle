#!/bin/sh
# Deploys the hive. .github/workflows/deploy.yml runs this on the runner when
# main moves, and the desktop runs it by hand as the fallback. Builds happen
# on whichever one runs it, through scripts/quietly.sh, and colmena pushes
# each closure over SSH and switches the host. The mini builds on itself, and
# the runner holds no key to it, so only the desktop applies it.
#
#   scripts/deploy.sh plex rss    # these hosts
#   scripts/deploy.sh             # every server: the deploy tag, then dns2
#
# The two DNS guests never switch together: dns2 waits until dns1 answers
# again, so the LAN always has a resolver.
set -eu

root="$(git rev-parse --show-toplevel)"
cd "$root"

if [ $# -gt 0 ]; then
  exec scripts/quietly.sh colmena apply --on "$(
    IFS=,
    printf '%s' "$*"
  )"
fi

servers=@deploy
if [ -z "${GITHUB_ACTIONS:-}" ]; then
  servers=@deploy,@deploy-mini
fi

scripts/quietly.sh colmena apply --on "$servers"

for attempt in $(seq 30); do
  if dig +short +time=2 +tries=1 @dns1 auth.shaneplunkett.com A | grep -q '^[^;]'; then
    break
  fi
  if [ "$attempt" -eq 30 ]; then
    echo "deploy: dns1 isn't answering, so dns2 keeps its current config" >&2
    exit 1
  fi
  sleep 2
done

exec scripts/quietly.sh colmena apply --on @deploy-after-dns1
