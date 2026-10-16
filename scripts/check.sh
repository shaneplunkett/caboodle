#!/bin/sh
# The gate: the one check for this repo. Pre-commit, CI and the agents'
# hooks all run exactly this, so there's one answer to "is the repo clean".
# Terraform is checked offline: validate needs the providers' schemas but
# not the backend, so it runs without any tokens. The plan stays in CI.
set -eu
cd "$(git rev-parse --show-toplevel)"

scripts/check-suppressions.sh

git ls-files --cached --others --exclude-standard -z '*.nix' | xargs -0 -r nixfmt --check
statix check .
deadnix --fail .

ruff format --check .
ruff check .
git ls-files --cached --others --exclude-standard -z '*.py' | xargs -0 -r mypy

biome ci --colors=off --error-on-warnings .

git ls-files --cached --others --exclude-standard -z '*.sh' | xargs -0 -r shfmt -d
git ls-files --cached --others --exclude-standard -z '*.sh' | xargs -0 -r shellcheck

unformatted="$(git ls-files --cached --others --exclude-standard -z '*.go' | xargs -0 -r gofmt -l)"
if [ -n "$unformatted" ]; then
  echo "gofmt would change:"
  echo "$unformatted"
  exit 1
fi

terraform fmt -check -recursive terraform
if ! init="$(terraform -chdir=terraform init -backend=false -input=false -no-color 2>&1)"; then
  echo "$init"
  exit 1
fi
terraform -chdir=terraform validate -no-color
tflint --chdir=terraform --recursive --config "$PWD/terraform/.tflint.hcl" -f compact
