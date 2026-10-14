{ config, ... }:
let
  dataDir = config.services.tautulli.dataDir;
in
{
  homelab = {
    backup = {
      paths = [ dataDir ];
      exclude = map (path: "${dataDir}/${path}") [
        "backups"
        "cache"
        "logs"
      ];
    };

    arr.databases = [ "${dataDir}/tautulli.db" ];
  };

  services.tautulli = {
    enable = true;
    openFirewall = true;
  };
}
