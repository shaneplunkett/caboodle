{ config, ... }:

let
  secrets = config.age.secrets;
in
{
  homelab.secrets = [ "proxmox-token" ];

  services.homepage-dashboard = {
    enable = true;
    openFirewall = true;
    allowedHosts = "dashboard.shaneplunkett.com,${config.homelab.lanAddress}:8082";
    environmentFiles = [ secrets.proxmox-token.path ];
    services = [
      {
        "Infrastructure" = [
          {
            "PVE" = {
              href = "https://proxmox.shaneplunkett.com";
              description = "Proxmox";
              icon = "proxmox.png";
              widget = {
                type = "proxmox";
                url = "https://proxmox.shaneplunkett.com";
                username = "homepage@pve!dashboard";
                password = "{{HOMEPAGE_VAR_PROXMOX_TOKEN}}";
              };
            };
          }
        ];

      }
    ];
  };
}
