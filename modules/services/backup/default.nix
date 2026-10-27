{
  config,
  lib,
  pkgs,
  name,
  ...
}:
let
  cfg = config.homelab.backup;

  restic = pkgs.writeShellScriptBin "restic" ''
    exec ${lib.getExe' pkgs.util-linux "flock"} /run/lock/restic ${lib.getExe pkgs.restic} "$@"
  '';

  knownHosts = pkgs.writeText "storagebox-known-hosts" (
    lib.concatMapStrings (key: "[${cfg.storageBox}]:23 ${key}\n") [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIICf9svRenC/PLKIL9nk6K/pxQgoiFC41wTNvoIncOxs"
      "ecdsa-sha2-nistp521 AAAAE2VjZHNhLXNoYTItbmlzdHA1MjEAAAAIbmlzdHA1MjEAAACFBAGK0po6usux4Qv2d8zKZN1dDvbWjxKkGsx7XwFdSUCnF19Q8psHEUWR7C/LtSQ5crU/g+tQVRBtSgoUcE8T+FWp5wBxKvWG2X9gD+s9/4zRmDeSJR77W6gSA/+hpOZoSE+4KgNdnbYSNtbZH/dN74EG7GLb/gcIpbUUzPNXpfKl7mQitw=="
      "ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEA5EB5p/5Hp3hGW1oHok+PIOH9Pbn7cnUiGmUEBrCVjnAw+HrKyN8bYVV0dIGllswYXwkG/+bgiBlE6IVIBAq+JwVWu1Sss3KarHY3OvFJUXZoZyRRg/Gc/+LRCE7lyKpwWQ70dbelGRyyJFH36eNv6ySXoUYtGkwlU5IVaHPApOxe4LHPZa/qhSRbPo2hwoh0orCtgejRebNtW5nlx00DNFgsvn8Svz2cIYLxsPVzKgUxs8Zxsxgn+Q/UvR7uq4AbAhyBMLxv7DjJ1pc7PJocuTno2Rw9uMZi1gkjbnmiOh6TTXIEWbnroyIhwc8555uto9melEUmWNQ+C+PwAK+MPw=="
    ]
  );

  storageBox = {
    repository = "rclone::sftp:restic";
    environmentFile = config.age.secrets."backup-${name}".path;
    package = restic;
    extraOptions = [ "rclone.program=${lib.getExe pkgs.rclone}" ];
    rcloneOptions = {
      sftp-host = cfg.storageBox;
      sftp-port = "23";
      sftp-known-hosts-file = "${knownHosts}";
      sftp-disable-hashcheck = true;
    };
  };

  r2 = {
    repository = "s3:https://${cfg.r2Account}.r2.cloudflarestorage.com/restic-${name}";
    environmentFile = config.age.secrets."backup-r2-${name}".path;
    package = restic;
    extraOptions = [ "s3.region=auto" ];
  };

  jobs = job: repository: schedule: {
    ${job} = repository // {
      inherit (cfg) paths exclude;
      backupPrepareCommand = lib.mkIf (cfg.prepare != "") cfg.prepare;
      initialize = true;
      extraBackupArgs = [ "--one-file-system" ];
      timerConfig = lib.mapNullable (time: {
        OnCalendar = "${time} Australia/Melbourne";
        RandomizedDelaySec = "1h";
        Persistent = true;
      }) schedule.backup;
    };

    "${job}-prune" = repository // {
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      runCheck = false;
      createWrapper = false;
      timerConfig = {
        OnCalendar = "${schedule.prune} Australia/Melbourne";
        Persistent = true;
      };
    };

    "${job}-check" = repository // {
      checkOpts = [ "--read-data-subset=1/10" ];
      createWrapper = false;
      timerConfig = {
        OnCalendar = "${schedule.check} Australia/Melbourne";
        Persistent = true;
      };
    };
  };

  tasks = {
    homelab = "backup";
    homelab-prune = "prune";
    homelab-check = "check";
    r2 = "r2-backup";
    r2-prune = "r2-prune";
    r2-check = "r2-check";
  };

  stamp =
    task:
    pkgs.writeShellScript "stamp-${task}" ''
      file=${config.homelab.metricsDir}/backup-${task}.prom
      echo "homelab_backup_last_success_timestamp_seconds{task=\"${task}\"} $(date +%s)" > "$file.tmp"
      mv "$file.tmp" "$file"
    '';
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf (cfg.paths != [ ]) {
    assertions = map (path: {
      assertion = path != "/mnt" && !lib.hasPrefix "/mnt/" path;
      message = "homelab.backup.paths: ${path} is under /mnt, where the NAS shares are mounted.";
    }) cfg.paths;

    homelab.secrets = [
      "backup-${name}"
      "backup-r2-${name}"
    ];

    services.restic.backups =
      jobs "homelab" storageBox {
        backup = "03:00";
        prune = "Sun 05:00";
        check = "Wed 05:00";
      }
      // jobs "r2" r2 {
        backup = null;
        prune = "Sun 06:00";
        check = "Thu 05:00";
      };

    systemd.services = lib.mkMerge [
      (lib.mapAttrs' (
        job: task: lib.nameValuePair "restic-backups-${job}" { serviceConfig.ExecStartPost = stamp task; }
      ) tasks)
      {
        restic-backups-homelab.wants = [ "restic-backups-r2.service" ];
        restic-backups-r2.after = [ "restic-backups-homelab.service" ];
      }
    ];
  };
}
