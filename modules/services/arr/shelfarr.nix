let
  dataDir = "/var/lib/shelfarr";
  port = 8085;
in
{
  homelab = {
    backup = {
      paths = [ dataDir ];
      exclude = [ "${dataDir}/production_cache.sqlite3*" ];
    };

    arr.databases = map (db: "${dataDir}/${db}") [
      "production.sqlite3"
      "production_cable.sqlite3"
      "production_queue.sqlite3"
    ];
  };

  virtualisation.oci-containers.containers.shelfarr = {
    image = "ghcr.io/pedro-revez-silva/shelfarr@sha256:b4bbdf278cfe6aa4773b102c192ad9c79263c573fc8b51c5861d1a093f9e9092";
    ports = [ "${toString port}:3000" ];
    volumes = [
      "${dataDir}:/rails/storage"
      "/mnt/media:/mnt/media"
    ];
    environment = {
      PUID = "99";
      PGID = "100";
      TZ = "Australia/Melbourne";
      SOLID_QUEUE_IN_PUMA = "true";
    };
    extraOptions = [ "--sysctl=net.ipv4.ip_unprivileged_port_start=0" ];
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 99 100 -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
