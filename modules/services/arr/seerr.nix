{ config, ... }:
let
  dataDir = "/var/lib/private/seerr";
in
{
  homelab = {
    routes.overseer = config.services.seerr.port;

    backup = {
      paths = [ dataDir ];
      exclude = [
        "${dataDir}/cache"
        "${dataDir}/logs"
      ];
    };

    arr.databases = [ "${dataDir}/db/db.sqlite3" ];
  };

  services.seerr = {
    enable = true;
    openFirewall = true;
  };
}
