module "gym" {
  source        = "./modules/nixos-lxc"
  hostname      = "gym"
  node_name     = local.pve.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:C4:3F:EC"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 1024
}
