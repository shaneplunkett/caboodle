module "paper" {
  source        = "./modules/nixos-lxc"
  hostname      = "paper"
  node_name     = local.cube.name
  ip            = "dhcp"
  lan_addresses = local.lan_addresses
  datastore     = proxmox_storage_lvmthin.cube_nvme.id
  memory        = 4096
  swap          = 1024
  disk_size     = 32
}
