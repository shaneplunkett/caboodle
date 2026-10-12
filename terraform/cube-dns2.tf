module "dns2" {
  source        = "./modules/nixos-lxc"
  hostname      = "dns2"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:B3:E3:C3"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 1024
  disk_size     = 8
}
