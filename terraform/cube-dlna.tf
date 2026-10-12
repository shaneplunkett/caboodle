module "dlna" {
  source        = "./modules/nixos-lxc"
  hostname      = "dlna"
  node_name     = local.cube.name
  node_ip       = local.cube.ip
  ip            = "dhcp"
  mac_address   = "BC:24:11:77:AD:79"
  lan_addresses = local.lan_addresses
  cores         = 1
  memory        = 512

  bind_mounts = {
    "/mnt/programs" = "/mnt/pve/unraid-programs"
  }
}
