data "external" "network" {
  program     = ["nix", "eval", "--json", "..#network", "--apply", "network: { json = builtins.toJSON network; }"]
  working_dir = path.root
}

locals {
  network       = jsondecode(data.external.network.result.json)
  lan_addresses = local.network.hosts
  pve = {
    ip      = local.network.devices.pve.ip
    name    = "pve"
    api_url = "https://${local.network.devices.pve.ip}:8006"
  }
  cube = {
    ip   = local.network.devices.cube.ip
    name = "cube"
  }

  backup_hosts = toset(["dashboard", "plex", "arr", "brain", "auth", "forge", "gym", "rss", "home", "photos", "paper"])
}
