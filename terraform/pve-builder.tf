module "builder" {
  source    = "./modules/nixos-lxc"
  hostname  = "builder"
  node_name = local.pve.name
  ip        = "dhcp"
  cores     = 20
  cpu_units = 10
  memory    = 49152
  swap      = 2048
  disk_size = 250
}
