data "cloudflare_account_api_token_permission_groups_list" "r2_bucket_write" {
  account_id = var.cloudflare_account_id
  name       = "Workers R2 Storage Bucket Item Write"
  scope      = "com.cloudflare.edge.r2.bucket"
}

resource "cloudflare_r2_bucket" "backup" {
  for_each      = local.backup_hosts
  account_id    = var.cloudflare_account_id
  name          = "restic-${each.key}"
  location      = "oc"
  storage_class = "Standard"
}

resource "cloudflare_account_token" "backup" {
  for_each   = local.backup_hosts
  account_id = var.cloudflare_account_id
  name       = "restic ${each.key}"

  policies = [{
    effect = "allow"
    permission_groups = [{
      id = data.cloudflare_account_api_token_permission_groups_list.r2_bucket_write.result[0].id
    }]
    resources = jsonencode({
      "com.cloudflare.edge.r2.bucket.${var.cloudflare_account_id}_default_${cloudflare_r2_bucket.backup[each.key].name}" = "*"
    })
  }]
}

output "r2_backup_credentials" {
  value = {
    for host, token in cloudflare_account_token.backup : host => {
      access_key_id     = token.id
      secret_access_key = sha256(token.value)
    }
  }
  sensitive = true
}
