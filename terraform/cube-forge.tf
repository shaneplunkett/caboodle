module "forge" {
  source        = "./modules/nixos-lxc"
  hostname      = "forge"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:12:40:4A"
  lan_addresses = local.lan_addresses
  cores         = 2
  memory        = 2048
  disk_size     = 32
}
