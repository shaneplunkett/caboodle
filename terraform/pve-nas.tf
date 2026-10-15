import {
  to = proxmox_virtual_environment_vm.nas
  id = "pve/117"
}

resource "proxmox_virtual_environment_vm" "nas" {
  name          = "nas"
  node_name     = local.pve.name
  vm_id         = 117
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["scsi0"]
  on_boot       = true
  started       = true

  agent {
    enabled = true
  }

  cpu {
    cores = 4
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = false
    type              = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    discard      = "on"
    iothread     = true
    file_format  = "raw"
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = upper(local.network.devices.unraid.mac)
    model       = "virtio"
  }

  hostpci {
    device = "hostpci0"
    id     = "0000:01:00"
    pcie   = false
    rombar = true
    xvga   = false
  }

  hostpci {
    device = "hostpci1"
    id     = "0000:04:00.0"
    pcie   = false
    rombar = true
    xvga   = false
  }

  serial_device {}

  operating_system {
    type = "l26"
  }
}
