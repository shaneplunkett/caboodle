provider "incus" {
  accept_remote_certificate = true

  remote {
    name    = "pve"
    address = "https://${local.network.devices.pve.ip}:8443"
  }

  remote {
    name    = "cube"
    address = "https://${local.network.devices.cube.ip}:8443"
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "unifi" {
  api_url        = "https://${local.network.gateway}"
  api_key        = var.unifi_api_key
  allow_insecure = true
}
