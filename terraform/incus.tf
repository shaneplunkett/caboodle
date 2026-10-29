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
  guest_vlans = merge([
    for name, guest in local.guests : {
      for vlan in guest.vlans : "${name}-${vlan.id}" => merge(vlan, { guest = name })
    }
  ]...)
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

resource "unifi_client" "guest_vlan" {
  for_each = local.guest_vlans
  mac      = lower(each.value.mac)
  name     = "${each.value.guest} (VLAN ${each.value.id})"
  fixed_ip = split("/", each.value.address)[0]
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

  dynamic "device" {
    for_each = { for i, vlan in each.value.vlans : "eth${i + 1}" => vlan }
    content {
      name = device.key
      type = "nic"
      properties = {
        nictype = "bridged"
        parent  = "br0"
        hwaddr  = lower(device.value.mac)
        vlan    = tostring(device.value.id)
      }
    }
  }

  dynamic "device" {
    for_each = each.value.mounts
    content {
      name = trim(replace(device.key, "/", "-"), "-")
      type = "disk"
      properties = {
        source = device.value
        path   = device.key
      }
    }
  }

  dynamic "device" {
    for_each = { for d in each.value.devices : trim(replace(d.path, "/", "-"), "-") => d }
    content {
      name = device.key
      type = "unix-char"
      properties = merge(
        { path = device.value.path },
        device.value.gid == null ? {} : { gid = tostring(device.value.gid) },
      )
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

  depends_on = [unifi_client.guest, unifi_client.guest_vlan]
}

moved {
  from = module.builder.unifi_client.this
  to   = unifi_client.guest["builder"]
}

moved {
  from = module.auth.unifi_client.this
  to   = unifi_client.guest["auth"]
}

moved {
  from = module.ingress.unifi_client.this
  to   = unifi_client.guest["ingress"]
}

moved {
  from = module.brain.unifi_client.this
  to   = unifi_client.guest["brain"]
}

moved {
  from = module.forge.unifi_client.this
  to   = unifi_client.guest["forge"]
}

moved {
  from = module.home.unifi_client.this
  to   = unifi_client.guest["home"]
}

moved {
  from = module.home.unifi_client.extra["BC:24:11:33:8D:CE"]
  to   = unifi_client.guest_vlan["home-20"]
}

moved {
  from = unifi_client.cube_guest["plex"]
  to   = unifi_client.guest["plex"]
}

moved {
  from = unifi_client.cube_guest["arr"]
  to   = unifi_client.guest["arr"]
}

moved {
  from = unifi_client.cube_guest["dlna"]
  to   = unifi_client.guest["dlna"]
}

moved {
  from = unifi_client.cube_guest["monitoring"]
  to   = unifi_client.guest["monitoring"]
}

moved {
  from = unifi_client.cube_guest["dns2"]
  to   = unifi_client.guest["dns2"]
}

moved {
  from = unifi_client.cube_guest["photos"]
  to   = unifi_client.guest["photos"]
}

moved {
  from = unifi_client.cube_guest["paper"]
  to   = unifi_client.guest["paper"]
}
