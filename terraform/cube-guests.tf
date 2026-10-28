# Cube's guests while Cube is reinstalled, from Proxmox containers into Incus
# ones. Terraform has let go of the containers, and their UniFi reservations
# wait here until each guest has a homelab.guest and moves to
# unifi_client.guest.
locals {
  cube_guest_macs = {
    plex       = "BC:24:11:AA:D1:7C"
    arr        = "BC:24:11:25:4D:73"
    dlna       = "BC:24:11:77:AD:79"
    monitoring = "BC:24:11:DD:65:EE"
    dns2       = "BC:24:11:B3:E3:C3"
    photos     = "BC:24:11:CA:51:3A"
    paper      = "BC:24:11:2A:A7:BB"
  }
}

resource "unifi_client" "cube_guest" {
  for_each = local.cube_guest_macs
  mac      = lower(each.value)
  name     = each.key
  fixed_ip = local.lan_addresses[each.key]
}

moved {
  from = module.plex.unifi_client.this
  to   = unifi_client.cube_guest["plex"]
}

moved {
  from = module.arr.unifi_client.this
  to   = unifi_client.cube_guest["arr"]
}

moved {
  from = module.dlna.unifi_client.this
  to   = unifi_client.cube_guest["dlna"]
}

moved {
  from = module.monitoring.unifi_client.this
  to   = unifi_client.cube_guest["monitoring"]
}

moved {
  from = module.dns2.unifi_client.this
  to   = unifi_client.cube_guest["dns2"]
}

moved {
  from = module.photos.unifi_client.this
  to   = unifi_client.cube_guest["photos"]
}

moved {
  from = module.paper.unifi_client.this
  to   = unifi_client.cube_guest["paper"]
}
