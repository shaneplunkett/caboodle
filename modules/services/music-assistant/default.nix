{ lib, pkgs, ... }:
let
  dataDir = "/var/lib/music-assistant";
  port = 8095;
  streamPort = 8097;
  sqlite = lib.getExe' pkgs.sqlite "sqlite3";
in
{
  homelab = {
    routes.music = port;

    backup = {
      paths = [ dataDir ];
      exclude = [
        "${dataDir}/library.db*"
        "${dataDir}/.cache"
      ];
      prepare = ''
        if [ -e ${dataDir}/library.db ]; then
          ${sqlite} ${dataDir}/library.db ".backup ${dataDir}/backup.db"
        fi
      '';
    };

    monitoring.units = [ "podman-music-assistant.service" ];
  };

  virtualisation.oci-containers.containers.music-assistant = {
    image = "ghcr.io/music-assistant/server:2.10.6";
    volumes = [ "${dataDir}:/data" ];
    environment.TZ = "Australia/Melbourne";
    extraOptions = [ "--network=host" ];
  };

  systemd.services.podman-music-assistant.environment.XDG_RUNTIME_DIR = "/run";

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 root root -" ];

  networking.firewall.allowedTCPPorts = [
    port
    streamPort
  ];
}
