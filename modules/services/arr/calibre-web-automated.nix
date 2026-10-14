let
  dataDir = "/var/lib/calibre-web-automated";
  port = 8083;
in
{
  homelab = {
    backup = {
      paths = [ dataDir ];
      exclude = map (path: "${dataDir}/${path}") [
        "log_archive"
        "processed_books"
        "thumbnails"
        "*.log"
      ];
    };

    arr.databases = map (db: "${dataDir}/${db}") [
      "app.db"
      "cwa.db"
    ];
  };

  virtualisation.oci-containers.containers.calibre-web-automated = {
    image = "docker.io/crocodilestick/calibre-web-automated:v4.0.8";
    ports = [ "${toString port}:${toString port}" ];
    volumes = [
      "${dataDir}:/config"
      "/mnt/media/library:/calibre-library"
      "/mnt/media/downloads/books-ingest:/cwa-book-ingest"
    ];
    environment = {
      PUID = "99";
      PGID = "100";
      TZ = "Australia/Melbourne";
      NETWORK_SHARE_MODE = "true";
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 99 100 -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
