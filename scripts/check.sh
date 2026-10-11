#!/bin/sh
# The one check for this repo. The agents' Stop hook, pre-commit and
# `scripts/check.sh` by hand all run exactly this, so there's one answer
# to "is the repo clean". Terraform is checked offline: validate needs the
# providers' schemas but not the backend, so it runs without any tokens.
# The plan stays in CI.
set -eu
cd "$(git rev-parse --show-toplevel)"

git ls-files --cached --others --exclude-standard -z '*.nix' | xargs -0 -r nixfmt --check
statix check .
deadnix --fail .

ruff format --check .
ruff check .

terraform fmt -check -recursive terraform
if ! init="$(terraform -chdir=terraform init -backend=false -input=false -no-color 2>&1)"; then
  echo "$init"
  exit 1
fi
terraform -chdir=terraform validate -no-color
tflint --chdir=terraform --recursive --config "$PWD/terraform/.tflint.hcl" -f compact

# A failing check gets fixed, not silenced. If a rule is wrong for the
# case, change statix.toml, ruff.toml or terraform/.tflint.hcl in the open.
if git grep --untracked -n -E 'tflint-ignore|deadnix: *skip|noqa|type: *ignore' -- '*.nix' '*.tf' '*.py'; then
  echo "Suppression comments aren't allowed. Fix the finding, or change the rule's config."
  exit 1
fi
