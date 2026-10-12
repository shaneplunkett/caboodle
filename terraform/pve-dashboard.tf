module "dashboard" {
  source        = "./modules/nixos-lxc"
  hostname      = "dashboard"
  node_name     = local.pve.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:C0:8C:06"
  lan_addresses = local.lan_addresses
}
