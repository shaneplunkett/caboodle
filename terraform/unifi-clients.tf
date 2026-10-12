locals {
  devices = {
    "Apple TV"                 = { mac = "f0:b3:ec:0a:fc:98", ip = "192.168.1.75" }
    "Nix-Desktop"              = { mac = "a8:a1:59:f0:68:ef", ip = "192.168.1.100" }
    "Bambu X1C"                = { mac = "50:41:1c:89:2f:40", ip = "192.168.1.106" }
    "Raspberry Pi 4"           = { mac = "e4:5f:01:95:0d:b9", ip = "192.168.1.162" }
    "JetKVM"                   = { mac = "30:52:53:07:0d:1c", ip = "192.168.1.168" }
    "Raspberry Pi 2"           = { mac = "b8:27:eb:b1:b8:7e", ip = "192.168.1.194" }
    "Mini"                     = { mac = "bc:74:ea:e8:00:97", ip = "192.168.1.252" }
    "Meross Plug 524f"         = { mac = "48:e1:e9:af:52:4f", ip = "192.168.20.15" }
    "Sensibo"                  = { mac = "94:b5:55:ae:d5:e8", ip = "192.168.20.22" }
    "LIFX Switch 6C55C7"       = { mac = "d0:73:d5:6c:55:c8", ip = "192.168.20.23" }
    "Gaggiuino"                = { mac = "a0:85:e3:f3:45:7c", ip = "192.168.20.29" }
    "Meross Plug dfb5"         = { mac = "48:e1:e9:a6:df:b5", ip = "192.168.20.47" }
    "Hue Bridge"               = { mac = "ec:b5:fa:8f:a1:b6", ip = "192.168.20.60" }
    "WiZ 3f1c36"               = { mac = "98:77:d5:3f:1c:36", ip = "192.168.20.106" }
    "Meross Strip d56c"        = { mac = "48:e1:e9:93:d5:6c", ip = "192.168.20.108" }
    "Balcony Shelly"           = { mac = "98:cd:ac:1e:a8:43", ip = "192.168.20.115" }
    "Dyson"                    = { mac = "44:6f:f8:5e:28:7d", ip = "192.168.20.123" }
    "Meross Smart Switch"      = { mac = "c4:e7:ae:1e:e4:83", ip = "192.168.20.128" }
    "Bose Soundbar (Ethernet)" = { mac = "c8:7b:23:b1:bc:78", ip = "192.168.20.134" }
    "Bose Soundbar"            = { mac = "c8:7b:23:b1:bc:7e", ip = "192.168.20.140" }
    "LIFX Switch 6C378F"       = { mac = "d0:73:d5:6c:37:90", ip = "192.168.20.161" }
    "SLZB"                     = { mac = "1c:69:20:92:8f:9f", ip = "192.168.20.192" }
    "Meross Strip de3a"        = { mac = "48:e1:e9:a4:de:3a", ip = "192.168.20.193" }
    "Meross Strip dc3c"        = { mac = "48:e1:e9:a4:dc:3c", ip = "192.168.20.220" }
    "Beast"                    = { mac = "e8:9c:25:7a:2d:c4", ip = local.pve.ip }
    "Cube"                     = { mac = "e0:d5:5e:84:3e:48", ip = local.cube.ip }
    "Unraid"                   = { mac = lower(proxmox_virtual_environment_vm.unraid.network_device[0].mac_address), ip = "192.168.1.132" }
  }
}

resource "unifi_client" "device" {
  for_each = local.devices
  mac      = each.value.mac
  name     = each.key
  fixed_ip = each.value.ip
}
