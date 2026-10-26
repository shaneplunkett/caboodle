resource "unifi_port_forward" "host" {
  for_each = { for forward in local.network.forwards : forward.name => forward }
  name     = each.key
  protocol = each.value.protocol

  wan = {
    interface  = "wan"
    ip_address = "any"
    port       = tostring(each.value.port)
  }

  forward = {
    ip   = each.value.ip
    port = tostring(each.value.port)
  }
}

moved {
  from = unifi_port_forward.plex
  to   = unifi_port_forward.host["plex"]
}
