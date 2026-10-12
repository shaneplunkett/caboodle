module "builder" {
  source        = "./modules/nixos-lxc"
  hostname      = "builder"
  node_name     = local.pve.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:CC:42:C2"
  lan_addresses = local.lan_addresses
  cores         = 20
  cpu_units     = 10
  memory        = 49152
  swap          = 2048
  disk_size     = 250
}
