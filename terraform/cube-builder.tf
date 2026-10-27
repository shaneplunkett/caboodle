module "builder" {
  source        = "./modules/nixos-lxc"
  hostname      = "builder"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:CC:42:C2"
  lan_addresses = local.lan_addresses
  cores         = 8
  cpu_units     = 10
  memory        = 20480
  swap          = 2048
  disk_size     = 250
}
