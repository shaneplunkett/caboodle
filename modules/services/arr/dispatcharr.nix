let
  dataDir = "/var/lib/dispatcharr";
  port = 9191;
in
{
  homelab = {
    routes.dispatcharr = port;

    backup = {
      paths = [ dataDir ];
      exclude = map (dir: "${dataDir}/${dir}") [
        "db"
        "logs"
      ];
    };
  };

  virtualisation.oci-containers.containers.dispatcharr = {
    image = "ghcr.io/dispatcharr/dispatcharr:0.33.0";
    ports = [ "${toString port}:${toString port}" ];
    volumes = [ "${dataDir}:/data" ];
    environment = {
      DISPATCHARR_ENV = "aio";
      REDIS_HOST = "localhost";
      CELERY_BROKER_URL = "redis://localhost:6379/0";
      TZ = "Australia/Melbourne";
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0755 root root -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
