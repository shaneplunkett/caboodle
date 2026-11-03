#!/bin/sh
# Pushes hosts' closures to the cache. Each one builds here, through
# scripts/quietly.sh, then `nix copy` ships the whole closure into the cache's
# store over SSH, and a profile per host keeps it through the cache's garbage
# collection. A host only builds on its own system, so the desktop and the
# runner push Linux hosts and the mini's runner pushes the Macs. It uses the
# name Blocky answers for, so a push doesn't depend on MagicDNS, which servers
# don't take and which the mini only gets from its Homebrew Tailscale app.
#
#   scripts/push-to-cache.sh plex rss
set -eu

cache=root@cache.home.arpa

if [ $# -eq 0 ]; then
  echo "usage: scripts/push-to-cache.sh <host> [<host>...]" >&2
  exit 2
fi

cd "$(git rev-parse --show-toplevel)"

for host in "$@"; do
  path="$(scripts/quietly.sh nix build --no-link --print-out-paths ".#hydraJobs.$host")"
  nix copy --to "ssh-ng://$cache" "$path"
  ssh "$cache" nix-env -p "/nix/var/nix/profiles/per-host/$host" --set "$path"
  echo "$host: $path"
done
