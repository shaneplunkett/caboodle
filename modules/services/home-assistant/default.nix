{ lib, pkgs, ... }:
let
  dataDir = "/var/lib/hass";
  port = 8123;
  sqlite = lib.getExe' pkgs.sqlite "sqlite3";
in
{
  homelab = {
    routes.home = port;

    oidcClients.home = {
      name = "Home Assistant";
      callbackURLs = [ "https://home.shaneplunkett.com/auth/oidc/callback" ];
      groups = [ "home_admins" ];
    };

    backup = {
      paths = [ dataDir ];
      exclude = [
        "${dataDir}/home-assistant_v2.db*"
        "${dataDir}/backups"
      ];
      prepare = ''
        if [ -e ${dataDir}/home-assistant_v2.db ]; then
          ${sqlite} ${dataDir}/home-assistant_v2.db ".backup ${dataDir}/backup.db"
        fi
      '';
    };

    monitoring.units = [ "podman-homeassistant.service" ];
  };

  virtualisation.oci-containers.containers.homeassistant = {
    image = "ghcr.io/home-assistant/home-assistant:2026.10.1";
    volumes = [
      "${dataDir}:/config"
      "${./dyson-fan-card.js}:/config/www/dyson-fan-card.js:ro"
    ];
    environment.TZ = "Australia/Melbourne";
    extraOptions = [
      "--network=host"
      "--cap-add=NET_RAW"
    ];
  };

  systemd.services.podman-homeassistant.environment.XDG_RUNTIME_DIR = "/run";

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 root root -" ];

  environment.etc."systemd/network/eth0.network.d/50-accept-ra.conf".text = ''
    [Network]
    IPv6AcceptRA=true
  '';

  networking.firewall = {
    allowedTCPPorts = [ port ];
    allowedUDPPorts = [ 5353 ];
  };
}
