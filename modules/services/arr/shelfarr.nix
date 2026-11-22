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
    image = "ghcr.io/pedro-revez-silva/shelfarr@sha256:97270513a75354d1b8cf2fa68f22cd31f021d03c3695186437e448f2a9255d9e";
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
