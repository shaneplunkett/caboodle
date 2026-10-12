module "ingress" {
  source        = "./modules/nixos-lxc"
  hostname      = "ingress"
  node_name     = local.pve.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:42:4E:7D"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 1024
  disk_size     = 8
}
