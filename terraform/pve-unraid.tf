import {
  to = proxmox_virtual_environment_vm.unraid
  id = "pve/100"
}

resource "proxmox_virtual_environment_vm" "unraid" {
  name          = "Unraid"
  description   = "Unraid VM"
  node_name     = local.pve.name
  vm_id         = 100
  bios          = "ovmf"
  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  boot_order    = ["usb0"]
  on_boot       = false
  started       = false

  cpu {
    cores   = 4
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
  }

  efi_disk {
    datastore_id      = "local-lvm"
    file_format       = "raw"
    pre_enrolled_keys = true
    type              = "4m"
  }

  network_device {
    bridge      = "vmbr0"
    firewall    = true
    mac_address = upper(local.network.devices.unraid.mac)
    model       = "e1000"
  }

  hostpci {
    device = "hostpci1"
    id     = "0000:01:00"
    pcie   = false
    rombar = true
    xvga   = false
  }

  hostpci {
    device = "hostpci2"
    id     = "0000:04:00.0"
    pcie   = false
    rombar = true
    xvga   = false
  }

  usb {
    host = "5-2"
  }

  operating_system {
    type = "l26"
  }
}
