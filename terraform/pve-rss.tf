module "rss" {
  source      = "./modules/nixos-lxc"
  hostname    = "rss"
  node_name   = local.pve.name
  ip          = "dhcp"
  mac_address = "BC:24:11:FD:C5:8A"
  reserved_ip = "192.168.1.153"
  cores       = 1
  memory      = 1024
}
