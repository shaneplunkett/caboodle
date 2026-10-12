data "unifi_network" "lan" {
  count = var.reserved_ip != null ? 1 : 0
  name  = "LAN"
}

resource "unifi_client" "this" {
  count      = var.reserved_ip != null ? 1 : 0
  mac        = lower(var.mac_address)
  name       = var.hostname
  fixed_ip   = var.reserved_ip
  network_id = data.unifi_network.lan[0].id

  lifecycle {
    precondition {
      condition     = var.mac_address != null
      error_message = "reserved_ip needs mac_address, since UniFi reserves by MAC."
    }
  }
}
