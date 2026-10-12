resource "unifi_client" "device" {
  for_each = { for device in values(local.network.devices) : device.name => device }
  mac      = each.value.mac
  name     = each.key
  fixed_ip = each.value.ip
}
