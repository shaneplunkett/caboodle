#!/bin/sh
# Terraform, from the desktop or the deploy job. The tokens are the
# terraform-*.age secrets in modules/agenix, so nothing is copied into a CI
# secret store. The desktop decrypts them with Shane's key. The runner's agenix
# has already put them in /run/agenix, and the job says so with
# TERRAFORM_SECRETS_DIR, so it needs neither agenix nor the dev shell.
#
#   scripts/terraform.sh          # plan
#   scripts/terraform.sh apply    # plan, then apply that plan
#
# The Incus provider reads its client certificate from INCUS_CONF. The job only
# applies what scripts/terraform-guard.sh passes, and the desktop applies anything.
set -eu

if [ -z "${TERRAFORM_SECRETS_DIR:-}" ]; then
  if ! command -v terraform >/dev/null 2>&1 || ! command -v agenix >/dev/null 2>&1; then
    exec "$(dirname "$0")/in-dev-shell.sh" "$0" "$@"
  fi
fi

mode="${1:-plan}"
root="$(git rev-parse --show-toplevel)"

creds="$(mktemp -d)"
trap 'rm -rf "$creds"' EXIT
secret() {
  if [ -n "${TERRAFORM_SECRETS_DIR:-}" ]; then
    cat "$TERRAFORM_SECRETS_DIR/terraform-$1"
  else
    (cd "$root/modules/agenix" && agenix -d "terraform-$1.age")
  fi
}

TF_TOKEN_app_terraform_io="$(secret cloud-token)"
TF_VAR_hcloud_token="$(secret hcloud-token)"
TF_VAR_cloudflare_api_token="$(secret cloudflare-token)"
TF_VAR_access_editor_emails="$(secret access-emails)"
TF_VAR_unifi_api_key="$(secret unifi-token)"
export TF_TOKEN_app_terraform_io TF_VAR_hcloud_token TF_VAR_cloudflare_api_token TF_VAR_access_editor_emails TF_VAR_unifi_api_key

INCUS_CONF="$creds"
cp "$root/modules/services/incus/terraform.crt" "$INCUS_CONF/client.crt"
(umask 077 && secret incus-key >"$INCUS_CONF/client.key")
export INCUS_CONF

cd "$root/terraform"
terraform init -input=false -no-color >/dev/null
terraform plan -input=false -no-color -lock-timeout=10m -out="$creds/tfplan"

if [ "$mode" = apply ]; then
  if [ -n "${TERRAFORM_SECRETS_DIR:-}" ]; then
    terraform show -json -no-color "$creds/tfplan" >"$creds/tfplan.json"
    "$root/scripts/terraform-guard.sh" "$creds/tfplan.json"
  fi
  terraform apply -input=false -no-color -lock-timeout=10m "$creds/tfplan"
fi
