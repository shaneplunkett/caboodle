provider "proxmox" {
  endpoint  = local.cube.api_url
  api_token = var.pve_api_token
  insecure  = true

  ssh {
    agent    = false
    username = "shane"

    node {
      name    = local.cube.name
      address = local.cube.ip
    }
  }
}

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

provider "forgejo" {
  host      = "https://git.shaneplunkett.com"
  api_token = var.forgejo_api_token
}
