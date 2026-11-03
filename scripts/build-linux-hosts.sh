#!/bin/sh
# Builds every Linux host in the hive, the hand-switched ones included, and
# prints their names for scripts/push-to-cache.sh. .github/workflows/deploy.yml
# runs this on the runner before anything switches, so a merge that breaks PVE
# fails on the day rather than at its next switch.
#
# The dry run is the evaluation. It fills Nix's eval cache and exits, so its heap
# is gone before the compilers start, and the build after it and each build in
# push-to-cache.sh read the cache instead of evaluating. A dirty tree has no eval
# cache, so each of those evaluates again.
#
# With CLOSURE_LINKS set, the results are linked under that directory, and the
# links are GC roots: a collection can't take a closure between this build and
# its push. Remove the directory when the run is done and nothing roots them.
#
#   scripts/push-to-cache.sh $(scripts/build-linux-hosts.sh)
#   CLOSURE_LINKS=/tmp/closures scripts/build-linux-hosts.sh
set -eu

cd "$(git rev-parse --show-toplevel)"

hosts="$(scripts/quietly.sh nix eval --raw .#linuxHosts --apply toString)"

set --
for host in $hosts; do
  set -- "$@" ".#hydraJobs.$host"
done

scripts/quietly.sh nix build --dry-run "$@" >&2
if [ -n "${CLOSURE_LINKS:-}" ]; then
  mkdir -p "$CLOSURE_LINKS"
  scripts/quietly.sh nix build --out-link "$CLOSURE_LINKS/system" --keep-going "$@" >&2
else
  scripts/quietly.sh nix build --no-link --keep-going "$@" >&2
fi

echo "$hosts"
