module "home" {
  source        = "./modules/nixos-lxc"
  hostname      = "home"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:21:E0:4E"
  lan_addresses = local.lan_addresses
  cores         = 2
  memory        = 3072
  disk_size     = 16

  extra_networks = [
    {
      vlan_id     = 20
      mac_address = "BC:24:11:33:8D:CE"
      ip          = "192.168.20.117/24"
    },
  ]
}
