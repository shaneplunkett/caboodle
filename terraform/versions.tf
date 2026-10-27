terraform {
  required_version = ">=1.5.0"
  cloud {

    organization = "metrokitten"

    workspaces {
      name = "homelab"
    }
  }
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.69.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.27"
    }
    forgejo = {
      source  = "svalabs/forgejo"
      version = "~> 1.6"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
    unifi = {
      source  = "ubiquiti-community/unifi"
      version = "0.59.0"
    }
    incus = {
      source  = "lxc/incus"
      version = "~> 1.2"
    }

  }
}
