#!/bin/sh
# Builds every Linux host in the hive, the hand-switched ones included, and
# prints their names for scripts/push-to-cache.sh. .github/workflows/deploy.yml
# runs this on the runner before anything switches, so a merge that breaks PVE
# fails on the day rather than at its next switch.
#
# The dry run is the evaluation. It fills Nix's eval cache and exits, so its heap
# is gone before the compilers start, and each build after it and each build in
# push-to-cache.sh read the cache instead of evaluating. A dirty tree has no eval
# cache, so each of those evaluates again.
#
# Each host then gets its own nix build, because the daemon's worker for a call
# holds the goal graph of every derivation in that call until it exits. A host
# that fails doesn't stop the ones after it, and the failures are listed on stderr
# at the end. Stdout carries the host names only when every host built, so a
# failure leaves push-to-cache.sh nothing to push. An interrupt stops the loop,
# since nix exits on one like any other failure and the next host would start.
#
# With CLOSURE_LINKS set, each result is linked at $CLOSURE_LINKS/<host>, and the
# links are GC roots: a collection can't take a closure between this build and
# its push. Remove the directory when the run is done and nothing roots them.
#
#   scripts/push-to-cache.sh $(scripts/build-linux-hosts.sh)
#   CLOSURE_LINKS=/tmp/closures scripts/build-linux-hosts.sh
set -eu

trap 'exit 130' INT

cd "$(git rev-parse --show-toplevel)"

hosts="$(scripts/quietly.sh nix eval --raw .#linuxHosts --apply toString)"

set --
for host in $hosts; do
  set -- "$@" ".#hydraJobs.$host"
done

scripts/quietly.sh nix build --dry-run "$@" >&2

if [ -n "${CLOSURE_LINKS:-}" ]; then
  mkdir -p "$CLOSURE_LINKS"
fi

failed=""
for host in $hosts; do
  if [ -n "${CLOSURE_LINKS:-}" ]; then
    set -- --out-link "$CLOSURE_LINKS/$host"
  else
    set -- --no-link
  fi
  if ! scripts/quietly.sh nix build "$@" --keep-going ".#hydraJobs.$host" >&2; then
    failed="$failed $host"
  fi
done

if [ -n "$failed" ]; then
  echo "build-linux-hosts: these hosts didn't build:$failed" >&2
  exit 1
fi

echo "$hosts"
