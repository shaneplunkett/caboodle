module "plex" {
  source        = "./modules/nixos-lxc"
  hostname      = "plex"
  node_name     = local.cube.name
  node_ip       = local.cube.ip
  ip            = "dhcp"
  mac_address   = "BC:24:11:AA:D1:7C"
  lan_addresses = local.lan_addresses
  cores         = 4
  memory        = 8192
  swap          = 1024
  disk_size     = 100

  devices = [
    { path = "/dev/dri/renderD128", gid = 303 },
  ]

  bind_mounts = {
    "/mnt/media" = "/mnt/pve/unraid-media"
  }
}
