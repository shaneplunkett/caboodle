module "monitoring" {
  source        = "./modules/nixos-lxc"
  hostname      = "monitoring"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:DD:65:EE"
  lan_addresses = local.lan_addresses
  cores         = 4
  memory        = 6144
  disk_size     = 40
}
