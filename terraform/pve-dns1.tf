module "dns1" {
  source        = "./modules/nixos-lxc"
  hostname      = "dns1"
  node_name     = local.pve.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:10:29:FC"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 1024
  disk_size     = 8
}
