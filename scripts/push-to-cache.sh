#!/bin/sh
# Pushes hosts' closures to the cache. Each one builds here, through
# scripts/quietly.sh, then `nix copy` ships the whole closure into the cache's
# store over SSH, and a profile per host keeps it through the cache's garbage
# collection. Linux hosts only, since the desktop can't build darwin.
#
#   scripts/push-to-cache.sh plex rss
set -eu

if [ $# -eq 0 ]; then
  echo "usage: scripts/push-to-cache.sh <host> [<host>...]" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

for host in "$@"; do
  path="$(scripts/quietly.sh nix build --no-link --print-out-paths ".#hydraJobs.$host")"
  nix copy --to ssh-ng://root@cache "$path"
  ssh root@cache nix-env -p "/nix/var/nix/profiles/per-host/$host" --set "$path"
  echo "$host: $path"
done
