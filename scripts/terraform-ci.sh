#!/usr/bin/env bash
# Terraform on the builder's runner, for the pull request plan and the
# deploy's apply alike, so both see the same tokens and flags. Writes the
# plan to terraform/plan.txt for the pull request comment. A GitHub job
# writes the same files from its Actions secrets and points
# TERRAFORM_CREDENTIALS at them.
#
#   scripts/terraform-ci.sh [plan|apply]   # default: plan
#
# A plan and an apply can overlap, since they run in different workflows,
# so each waits for Terraform Cloud's state lock rather than failing on it.
set -euo pipefail

mode="${1:-plan}"
creds="${TERRAFORM_CREDENTIALS:-/run/credentials/forgejo-runner-builder.service}"

TF_TOKEN_app_terraform_io="$(<"$creds/terraform-cloud-token")"
TF_VAR_hcloud_token="$(<"$creds/terraform-hcloud-token")"
TF_VAR_cloudflare_api_token="$(<"$creds/terraform-cloudflare-token")"
TF_VAR_access_editor_emails="$(<"$creds/terraform-access-emails")"
TF_VAR_forgejo_api_token="$(<"$creds/terraform-forgejo-token")"
TF_VAR_unifi_api_key="$(<"$creds/terraform-unifi-token")"
export TF_TOKEN_app_terraform_io TF_VAR_hcloud_token TF_VAR_cloudflare_api_token TF_VAR_access_editor_emails TF_VAR_forgejo_api_token TF_VAR_unifi_api_key

root="$(git rev-parse --show-toplevel)"

# The Incus provider reads its client certificate from INCUS_CONF.
INCUS_CONF="$(mktemp -d)"
trap 'rm -rf "$INCUS_CONF"' EXIT
cp "$root/modules/services/incus/terraform.crt" "$INCUS_CONF/client.crt"
install -m 600 "$creds/terraform-incus-key" "$INCUS_CONF/client.key"
export INCUS_CONF

cd "$root/terraform"
terraform init -input=false -no-color
terraform plan -input=false -no-color -lock-timeout=10m -out=tfplan | tee plan.txt

if [ "$mode" = apply ]; then
  terraform apply -input=false -no-color -lock-timeout=10m tfplan
fi
