{
  config,
  lib,
  pkgs,
  ...
}:
let
  secrets = config.age.secrets;
  dir = "/var/lib/mirror";
  lock = "/run/lock/restic";

  mirror = pkgs.writeShellApplication {
    name = "mirror";
    runtimeInputs = [
      pkgs.curl
      pkgs.git
      pkgs.jq
      pkgs.openssl
    ];
    text = builtins.readFile ./mirror.sh;
  };
in
{
  homelab = {
    secrets = [
      "github-app-client-id"
      "github-app-private-key"
    ];
    monitoring.units = [ "mirror.service" ];
    backup.paths = [ dir ];
  };

  users.users.mirror = {
    uid = 900;
    group = "mirror";
    isSystemUser = true;
    home = dir;
  };
  users.groups.mirror.gid = 900;

  programs.git = {
    enable = true;
    config.safe.directory = "${dir}/*";
  };

  systemd.tmpfiles.rules = [ "f ${lock} 0644 root root -" ];

  systemd.services.mirror = {
    description = "Fetch every repo on GitHub into a bare clone";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.RequiresMountsFor = [ dir ];
    serviceConfig = {
      Type = "oneshot";
      User = "mirror";
      Group = "mirror";
      ExecStart = "${lib.getExe' pkgs.util-linux "flock"} ${lock} ${lib.getExe mirror} shaneplunkett ${dir}";
      LoadCredential = [
        "client-id:${secrets.github-app-client-id.path}"
        "private-key:${secrets.github-app-private-key.path}"
      ];
    };
  };

  systemd.timers.mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      RandomizedDelaySec = "10m";
      Persistent = true;
    };
  };
}
