# Cube stops being Proxmox at its install, and these would fail every plan
# once its API is gone. Terraform forgets them, and nothing is destroyed.

removed {
  from = module.plex.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.arr.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.dlna.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.monitoring.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.dns2.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.photos.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.paper.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.plex.terraform_data.root_only
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.arr.terraform_data.root_only
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.dlna.terraform_data.root_only
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.paper.random_id.mac
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_storage_nfs.unraid_media
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_storage_nfs.unraid_appdata
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_storage_nfs.unraid_programs
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_storage_lvmthin.cube_nvme
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_virtual_environment_dns.node
  lifecycle {
    destroy = false
  }
}

removed {
  from = terraform_data.node_exporter
  lifecycle {
    destroy = false
  }
}
