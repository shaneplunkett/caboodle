module "photos" {
  source      = "./modules/nixos-lxc"
  hostname    = "photos"
  node_name   = local.cube.name
  ip          = "dhcp"
  mac_address = "BC:24:11:CA:51:3A"
  reserved_ip = "192.168.1.154"
  datastore   = proxmox_storage_lvmthin.cube_nvme.id
  cores       = 4
  memory      = 8192
  swap        = 1024
  disk_size   = 250
}
