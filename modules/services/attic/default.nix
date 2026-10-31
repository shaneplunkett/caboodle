{ config, ... }:
let
  port = 8080;
in
{
  homelab.secrets = [ "attic-env" ];
  homelab.monitoring.units = [ "atticd.service" ];

  services.atticd = {
    enable = true;
    environmentFile = config.age.secrets.attic-env.path;
    settings = {
      listen = "[::]:${toString port}";
      allowed-hosts = [
        "cache.shaneplunkett.com"
        "${config.homelab.lanAddress}:${toString port}"
        "cache.tail1d49f8.ts.net:${toString port}"
      ];
      substituter-endpoint = "https://cache.shaneplunkett.com/";
      garbage-collection.default-retention-period = "6 weeks";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
