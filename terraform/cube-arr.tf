module "arr" {
  source        = "./modules/nixos-lxc"
  hostname      = "arr"
  node_name     = local.cube.name
  node_ip       = local.cube.ip
  ip            = "dhcp"
  mac_address   = "BC:24:11:25:4D:73"
  lan_addresses = local.lan_addresses
  cores         = 4
  memory        = 4096
  swap          = 1024
  disk_size     = 40

  bind_mounts = {
    "/mnt/media" = "/mnt/pve/unraid-media"
  }
}
