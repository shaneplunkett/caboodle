data "external" "incus_image" {
  program     = ["../scripts/incus-image.sh"]
  working_dir = path.root
}

locals {
  guests = local.network.guests
  generated_guest_macs = {
    for name, id in random_id.guest_mac : name => upper(join(":", concat(["10", "66", "6A"], regexall("..", id.hex))))
  }
  guest_macs = {
    for name, guest in local.guests : name => lower(coalesce(guest.mac, lookup(local.generated_guest_macs, name, null)))
  }
}

resource "random_id" "guest_mac" {
  for_each    = { for name, guest in local.guests : name => guest if guest.mac == null }
  byte_length = 3
}

resource "unifi_client" "guest" {
  for_each = local.guests
  mac      = local.guest_macs[each.key]
  name     = each.key
  fixed_ip = lookup(local.lan_addresses, each.key, null)

  lifecycle {
    precondition {
      condition     = lookup(local.lan_addresses, each.key, null) != null
      error_message = "${each.key} has no LAN address. Give it homelab.lanAddress in flake.nix."
    }
  }
}

# Guests only use the image when they're created, and colmena brings them up
# to date from there, so a newer image doesn't replace the old one. Replace it
# by hand with `terraform apply -replace` when it's worth refreshing.
resource "incus_image" "nixos" {
  for_each = toset([for guest in values(local.guests) : guest.host])
  remote   = each.key

  source_file = {
    data_path     = data.external.incus_image.result.rootfs
    metadata_path = data.external.incus_image.result.metadata
  }

  lifecycle {
    ignore_changes = [source_file]
  }
}

resource "incus_instance" "guest" {
  for_each = local.guests
  name     = each.key
  remote   = each.value.host
  image    = incus_image.nixos[each.value.host].fingerprint
  running  = each.value.running

  config = {
    "boot.autostart"   = "true"
    "limits.cpu"       = tostring(each.value.cores)
    "limits.memory"    = "${each.value.memory}MiB"
    "security.nesting" = "true"
  }

  device {
    name = "eth0"
    type = "nic"
    properties = {
      nictype = "bridged"
      parent  = "br0"
      hwaddr  = local.guest_macs[each.key]
    }
  }

  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "default"
      size = "${each.value.disk}GiB"
    }
  }

  lifecycle {
    ignore_changes = [image]
  }

  depends_on = [unifi_client.guest]
}

moved {
  from = module.builder.unifi_client.this
  to   = unifi_client.guest["builder"]
}

removed {
  from = module.builder.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

moved {
  from = module.auth.unifi_client.this
  to   = unifi_client.guest["auth"]
}

removed {
  from = module.auth.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

moved {
  from = module.ingress.unifi_client.this
  to   = unifi_client.guest["ingress"]
}

removed {
  from = module.ingress.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

moved {
  from = module.brain.unifi_client.this
  to   = unifi_client.guest["brain"]
}

removed {
  from = module.brain.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}

moved {
  from = module.forge.unifi_client.this
  to   = unifi_client.guest["forge"]
}

removed {
  from = module.forge.proxmox_virtual_environment_container.this
  lifecycle {
    destroy = false
  }
}
