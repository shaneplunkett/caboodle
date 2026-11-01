data "external" "network" {
  program     = ["nix", "eval", "--json", "..#network", "--apply", "network: { json = builtins.toJSON network; }"]
  working_dir = path.root
}

locals {
  network       = jsondecode(data.external.network.result.json)
  lan_addresses = local.network.hosts

  backup_hosts = toset(["plex", "arr", "brain", "auth", "forge", "gym", "rss", "home", "photos", "paper", "music", "recipes", "mirror"])
}
