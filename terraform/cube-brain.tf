module "brain" {
  source        = "./modules/nixos-lxc"
  hostname      = "brain"
  node_name     = local.cube.name
  ip            = "dhcp"
  mac_address   = "BC:24:11:D3:65:F1"
  lan_addresses = local.lan_addresses
  cores         = 4
  memory        = 8192
  swap          = 2048
  disk_size     = 64
}
