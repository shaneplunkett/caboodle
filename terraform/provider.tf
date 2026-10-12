provider "proxmox" {
  endpoint  = local.pve.api_url
  api_token = var.pve_api_token
  insecure  = true

  ssh {
    agent    = false
    username = "shane"

    node {
      name    = local.pve.name
      address = local.pve.ip

    }
    node {
      name    = local.cube.name
      address = local.cube.ip
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "unifi" {
  api_url        = "https://192.168.1.1"
  api_key        = var.unifi_api_key
  allow_insecure = true
}

provider "forgejo" {
  host      = "https://git.shaneplunkett.com"
  api_token = var.forgejo_api_token
}
