resource "hcloud_storage_box" "backups" {
  name             = "backups"
  storage_box_type = "bx11"
  location         = "hel1"
  password         = random_password.storage_box.result

  access_settings = {
    reachable_externally = true
    samba_enabled        = false
    ssh_enabled          = true
    webdav_enabled       = false
    zfs_enabled          = true
  }

  snapshot_plan = {
    max_snapshots = 10
    minute        = 16
    hour          = 18
    day_of_week   = 3
  }

  ssh_keys = [
    var.ssh_public_key
  ]

  lifecycle {
    ignore_changes = [
      ssh_keys
    ]

    prevent_destroy = true
  }
  delete_protection = true
}

resource "random_password" "storage_box" {
  length  = 32
  special = true
}

resource "random_password" "storage_box_host" {
  for_each         = local.backup_hosts
  length           = 32
  special          = true
  min_lower        = 1
  min_upper        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!$%/()=?+#-.,;:~*@{}_&"
}

resource "hcloud_storage_box_subaccount" "host" {
  for_each       = local.backup_hosts
  storage_box_id = hcloud_storage_box.backups.id
  name           = each.key
  home_directory = "hosts/${each.key}/"
  password       = random_password.storage_box_host[each.key].result
  description    = "restic backups for ${each.key}"

  access_settings = {
    reachable_externally = true
    ssh_enabled          = true
  }
}

output "storage_box_subaccounts" {
  value = {
    for host, account in hcloud_storage_box_subaccount.host : host => {
      username = account.username
      password = account.password
    }
  }
  sensitive = true
}
