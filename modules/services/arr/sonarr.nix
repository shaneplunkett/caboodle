{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.services.sonarr;
  sonarr = config.systemd.services.sonarr;
  anime = {
    dataDir = "/var/lib/sonarr-anime";
    port = 8990;
  };
  dataDirs = [
    cfg.dataDir
    anime.dataDir
  ];
in
{
  homelab = {
    secrets = [
      "sonarr"
      "sonarr-anime"
    ];
    routes = {
      sonarr = cfg.settings.server.port;
      sonarranime = anime.port;
    };

    backup = {
      paths = dataDirs;
      exclude = lib.concatMap (
        dir:
        map (path: "${dir}/${path}") [
          "Backups"
          "MediaCover"
          "Sentry"
          "logs"
          "logs.db*"
        ]
      ) dataDirs;
    };

    arr.databases = map (dir: "${dir}/sonarr.db") dataDirs;
  };

  services.sonarr = {
    enable = true;
    openFirewall = true;
    environmentFiles = [ config.age.secrets.sonarr.path ];
  };

  systemd.services.sonarr-anime = {
    description = "Sonarr Anime";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = sonarr.environment // {
      SONARR__SERVER__PORT = toString anime.port;
    };
    serviceConfig = sonarr.serviceConfig // {
      EnvironmentFile = [ config.age.secrets.sonarr-anime.path ];
      ExecStart = utils.escapeSystemdExecArgs [
        (lib.getExe cfg.package)
        "-nobrowser"
        "-data=${anime.dataDir}"
      ];
      StateDirectory = baseNameOf anime.dataDir;
    };
  };

  networking.firewall.allowedTCPPorts = [ anime.port ];
}
