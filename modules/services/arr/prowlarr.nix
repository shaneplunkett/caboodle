{ config, ... }:
let
  cfg = config.services.prowlarr;
  dataDir = "/var/lib/private/prowlarr";
in
{
  homelab = {
    secrets = [ "prowlarr" ];
    routes.prowlarr = cfg.settings.server.port;

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

    arr.databases = [ "${dataDir}/prowlarr.db" ];
  };

  services.prowlarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.age.secrets.prowlarr.path ];
    settings = {
      auth.required = "DisabledForLocalAddresses";
      server.allowedHosts = "prowlarr.shaneplunkett.com,${config.homelab.lanAddress}";
    };
  };
}
