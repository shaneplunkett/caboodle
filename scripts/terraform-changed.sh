#!/bin/sh
# Says whether a push to main changed terraform/, for the deploy job. Prints
# true or false.
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

if ! git cat-file -e "$before^{commit}" 2>/dev/null &&
  ! git fetch --quiet --depth=1 origin "$before" 2>/dev/null; then
  echo "terraform-changed: can't get $before, so assuming Terraform changed" >&2
  echo true
  exit 0
fi

if git diff --quiet "$before" "$after" -- terraform/; then
  echo false
else
  echo true
fi
