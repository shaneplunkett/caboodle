resource "random_id" "mac" {
  count       = var.mac_address == null ? 1 : 0
  byte_length = 3
}

locals {
  generated_mac = [for id in random_id.mac : upper(join(":", concat(["BC", "24", "11"], regexall("..", id.hex))))]
  mac_address   = coalesce(var.mac_address, one(local.generated_mac))
  lan_address   = lookup(var.lan_addresses, var.hostname, null)
}

resource "unifi_client" "this" {
  mac      = lower(local.mac_address)
  name     = var.hostname
  fixed_ip = local.lan_address

  lifecycle {
    precondition {
      condition     = local.lan_address != null
      error_message = "${var.hostname} has no LAN address. Add it to the hive in flake.nix with homelab.lanAddress."
    }
  }
}

resource "unifi_client" "extra" {
  for_each = { for network in var.extra_networks : network.mac_address => network }
  mac      = lower(each.key)
  name     = "${var.hostname} (VLAN ${each.value.vlan_id})"
  fixed_ip = split("/", each.value.ip)[0]
}

moved {
  from = unifi_client.this[0]
  to   = unifi_client.this
}
