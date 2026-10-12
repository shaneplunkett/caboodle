module "rss" {
  source        = "./modules/nixos-lxc"
  hostname      = "rss"
  node_name     = local.pve.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:FD:C5:8A"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 1024
}
