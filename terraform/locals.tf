data "external" "lan_addresses" {
  program     = ["nix", "eval", "--json", "..#lanAddresses"]
  working_dir = path.root
}

locals {
  lan_addresses = data.external.lan_addresses.result
  pve = {
    ip      = var.pve_ip
    name    = "pve"
    api_url = "https://${var.pve_ip}:8006"
  }
  cube = {
    ip   = var.cube_ip
    name = "cube"

  }
}
