{ config, ... }:
let
  cfg = config.services.radarr;
  inherit (cfg) dataDir;
in
{
  homelab = {
    secrets = [ "radarr" ];
    routes.radarr = cfg.settings.server.port;

    backup = {
      paths = [ dataDir ];
      exclude = map (path: "${dataDir}/${path}") [
        "Backups"
        "MediaCover"
        "Sentry"
        "logs"
        "logs.db*"
      ];
    };

    arr.databases = [ "${dataDir}/radarr.db" ];
  };

  services.radarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.age.secrets.radarr.path ];
  };
}
