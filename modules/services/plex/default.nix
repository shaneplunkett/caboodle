{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.plex;
  data = "${cfg.dataDir}/Plex Media Server";
  databases = "${data}/Plug-in Support/Databases";
  dumps = "${cfg.dataDir}/backup";
  postprocess = pkgs.writeShellApplication {
    name = "plex-dvr-hevc";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ffmpeg-headless
      pkgs.gawk
      pkgs.util-linux
    ];
    runtimeEnv = {
      LIBVA_DRIVER_NAME = "iHD";
      LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri";
    };
    text = builtins.readFile ./postprocess.sh;
  };
in
{
  homelab = {
    routes.plex = 32400;
    portForwards.plex = 32400;
    monitoring.units = [ "plex-dvr-hevc-install.service" ];

    backup = {
      paths = [ cfg.dataDir ];
      exclude = [
        "${databases}/*.db*"
      ]
      ++ map (dir: "${data}/${dir}") [
        "Cache"
        "Codecs"
        "Crash Reports"
        "Diagnostics"
        "Drivers"
        "Logs"
        "Media"
        "Metadata"
        "Updates"
      ];
      prepare = ''
        for db in "${databases}"/*.db; do
          ${lib.getExe' pkgs.util-linux "runuser"} -u ${cfg.user} -- \
            ${lib.getExe' pkgs.sqlite "sqlite3"} "$db" ".backup '${dumps}/$(basename "$db")'"
        done
      '';
    };
  };

  services.plex = {
    enable = true;
    openFirewall = true;
    accelerationDevices = [ "/dev/dri/renderD128" ];
  };

  users.groups.render.gid = config.ids.gids.render;
  users.users.${cfg.user}.extraGroups = [ "render" ];

  systemd.tmpfiles.rules = [ "d ${dumps} 0750 ${cfg.user} ${cfg.group} -" ];

  systemd.services.plex-dvr-hevc-install = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.coreutils "install"} -Dm555 ${lib.getExe postprocess} \"${data}/Scripts/${postprocess.name}\"";
    };
  };
}
