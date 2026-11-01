#!/bin/sh
# Runs a Nix build or evaluation on this machine without getting in Shane's
# way. The desktop builds the hive now, and it's also where she plays games,
# so a build never gets to win against what she's doing:
#
# - One at a time. A second caller waits on the lock instead of racing the
#   first, since two hive evaluations at once take a 32 GB box down.
# - Idle priority. The command runs under SCHED_IDLE and idle disk I/O, in a
#   systemd scope with CPUWeight=idle, so it only gets what nothing else
#   wants. The daemon's builds get the same from nix.daemon* in
#   modules/workstation/nixos.
# - Capped. The scope dies at 20 GB, so a runaway evaluation kills itself
#   before it kills the machine. The whole hive peaks around 15.
#
#   scripts/quietly.sh colmena apply --on plex
#   scripts/quietly.sh colmena build --on @deploy-on-merge
#   scripts/quietly.sh nix build .#hydraJobs.desktop
#
# On a Mac there's no systemd and no chrt, so it degrades to nice and the
# lock, which is all the mini needs.
set -eu

root="$(git rev-parse --show-toplevel)"
cd "$root"

lock="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/caboodle-build.lock"
exec 9>"$lock"
if ! flock -n 9; then
  echo "quietly: another build holds $lock, waiting for it" >&2
  flock 9
fi

if systemd-run --user --scope --quiet true 2>/dev/null; then
  set -- systemd-run --user --scope --quiet \
    -p MemoryMax=20G -p CPUWeight=idle -p IOWeight=1 \
    chrt --idle 0 ionice -c 3 "$@"
else
  set -- nice -n 20 "$@"
fi

exec "$@"
