resource "proxmox_virtual_environment_dns" "node" {
  for_each  = toset([local.pve.name, local.cube.name])
  node_name = each.key
  domain    = "shaneplunkett.com"
  servers = [
    local.lan_addresses.dns1,
    local.lan_addresses.dns2,
    local.network.gateway,
  ]
}
