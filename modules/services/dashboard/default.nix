{ config, ... }:
{
  services.homepage-dashboard = {
    enable = true;
    openFirewall = true;
    allowedHosts = "dashboard.shaneplunkett.com,${config.homelab.lanAddress}:8082";
  };
}
