#!/bin/sh
# Deploys the hive from the desktop. Builds happen here, through
# scripts/quietly.sh, and colmena pushes each closure over SSH and switches
# the host. The mini builds on itself, since the desktop can't build darwin.
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

scripts/quietly.sh colmena apply --on @deploy

for attempt in $(seq 30); do
  if dig +short +time=2 +tries=1 @dns1 git.shaneplunkett.com A | grep -q '^[^;]'; then
    break
  fi
  if [ "$attempt" -eq 30 ]; then
    echo "deploy: dns1 isn't answering, so dns2 keeps its current config" >&2
    exit 1
  fi
  sleep 2
done

exec scripts/quietly.sh colmena apply --on @deploy-after-dns1
