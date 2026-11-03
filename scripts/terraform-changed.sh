#!/bin/sh
# Says whether a push to main changed anything a Terraform plan reads, for the
# deploy job. Prints true or false.
#
#   scripts/terraform-changed.sh <before> <after>
#
# It compares the two commits' trees, so a rebase merge's several commits and a
# force push both count as what main went from and to. The job's checkout is one
# commit deep, and a tree diff only needs the before commit itself. Anything it
# can't tell prints true, because a plan that changes nothing is cheap and a
# skipped apply is the mistake the job exists to stop.
set -eu

before="$1"
after="$2"

# Terraform's own config, then what evaluating .#network and the Incus image
# reads, then the scripts the job plans through. The flake's overlays force the
# two files under pkgs/ but none of the packages they name.
set -- \
  terraform/ \
  flake.nix \
  flake.lock \
  hosts/ \
  modules/ \
  pkgs/overlays.nix \
  pkgs/default.nix \
  scripts/terraform.sh \
  scripts/terraform-changed.sh \
  scripts/terraform-guard.sh \
  scripts/incus-image.sh

if ! git cat-file -e "$before^{commit}" 2>/dev/null &&
  ! git fetch --quiet --depth=1 origin "$before" 2>/dev/null; then
  echo "terraform-changed: can't get $before, so assuming Terraform changed" >&2
  echo true
  exit 0
fi

if git diff --quiet "$before" "$after" -- "$@"; then
  echo false
else
  echo true
fi
