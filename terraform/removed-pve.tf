removed {
  from = module.rss
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.gym
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.dashboard
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.dns1
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_virtual_environment_vm.nas
  lifecycle {
    destroy = false
  }
}

removed {
  from = proxmox_virtual_environment_vm.unraid
  lifecycle {
    destroy = false
  }
}
