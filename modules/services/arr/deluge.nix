{ config, lib, ... }:
let
  cfg = config.services.deluge;
  configDir = "${cfg.dataDir}/.config/deluge";
  torrents = "/mnt/media/downloads/torrents";
in
{
  homelab = {
    secrets = [ "deluge-auth" ];
    routes.deluge = cfg.web.port;

    backup = {
      paths = [ configDir ];
      exclude = map (path: "${configDir}/${path}") [
        "auth"
        "core.conf*"
        "*.log"
        "*.pid"
      ];
    };
  };

  age.secrets.deluge-auth.owner = cfg.user;

  services.deluge = {
    enable = true;
    declarative = true;
    authFile = config.age.secrets.deluge-auth.path;

    web = {
      enable = true;
      openFirewall = true;
    };

    config = {
      download_location = "${torrents}/incomplete";
      move_completed = true;
      move_completed_path = "${torrents}/complete";
      enabled_plugins = [ "Label" ];
      new_release_check = false;

      max_active_downloading = 10;
      max_active_limit = 15;
      max_active_seeding = 5;
      max_connections_global = 500;
      max_upload_slots_global = 20;

      stop_seed_at_ratio = true;
      stop_seed_ratio = 1.0;
      remove_seed_at_ratio = true;
      share_ratio_limit = 0.0;
    };
  };

  systemd.services.delugeweb.preStart = ''
    if [ -f ${configDir}/web.conf ]; then
      sed -i -E 's/"session_timeout": [0-9]+/"session_timeout": ${toString (30 * 24 * 60 * 60)}/' ${configDir}/web.conf
    fi
  '';

  systemd.tmpfiles.settings."10-deluged" = lib.genAttrs [
    cfg.config.download_location
    cfg.config.move_completed_path
  ] (_: lib.mkForce { });
}
