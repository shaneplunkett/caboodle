resource "unifi_client" "this" {
  count    = var.reserved_ip != null ? 1 : 0
  mac      = lower(var.mac_address)
  name     = var.hostname
  fixed_ip = var.reserved_ip

  lifecycle {
    precondition {
      condition     = var.mac_address != null
      error_message = "reserved_ip needs mac_address, since UniFi reserves by MAC."
    }
  }
}
