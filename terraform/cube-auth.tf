module "auth" {
  source        = "./modules/nixos-lxc"
  hostname      = "auth"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:40:64:96"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 1024
  disk_size     = 8
}
