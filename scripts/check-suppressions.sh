#!/bin/sh
# Fails if any file silences a checker. Agents reach for these under
# pressure, so the ban is mechanical. --untracked scans new files too, and
# still skips anything gitignored. This script names every pattern, so it
# leaves itself out.
set -u

pattern='deadnix: *skip|tflint-ignore|noqa|type: *ignore|pyright: *ignore|fmt: *(off|skip)|@ts-ignore|@ts-nocheck|@ts-expect-error|oxlint-disable|eslint-disable|biome-ignore|shellcheck +disable'

if git grep --untracked -n -E "$pattern" -- \
  '*.nix' '*.tf' '*.py' '*.pyi' '*.sh' \
  '*.ts' '*.tsx' '*.mts' '*.cts' '*.js' '*.jsx' '*.mjs' '*.cjs' '*.css' '*.json' '*.jsonc' \
  ':!scripts/check-suppressions.sh'; then
  echo
  echo "Suppression comments aren't allowed. Fix the finding instead."
  echo "If a rule is wrong for this case, change its config in the open and say why."
  exit 1
fi
