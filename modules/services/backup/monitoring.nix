{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  links = import ../grafana/links.nix;
  box = config.homelab.backup.storageBox;
  usageFile = "${config.homelab.metricsDir}/storagebox.prom";

  backedUp = lib.attrNames (lib.filterAttrs (_: node: node.config.homelab.backup.paths != [ ]) nodes);

  maxAge = {
    backup = 36 * 3600;
    prune = 9 * 86400;
    check = 9 * 86400;
    r2-backup = 36 * 3600;
    r2-prune = 9 * 86400;
    r2-check = 9 * 86400;
  };

  jobs = {
    backup = "homelab";
    prune = "homelab-prune";
    check = "homelab-check";
    r2-backup = "r2";
    r2-prune = "r2-prune";
    r2-check = "r2-check";
  };

  stakes = {
    backup = "This job is the nightly copy of {{ $labels.host }}'s data to the Storage Box, so anything newer than its last good run has no copy there.";
    prune = "This job clears old snapshots out of {{ $labels.host }}'s Storage Box repo. Nothing is lost while it's stuck, but the repo keeps growing, and a full box stops every host's backups at once.";
    check = "This job reads back part of {{ $labels.host }}'s Storage Box repo to prove it can still be restored. Without it the backups may be fine, but damage stays hidden until a restore needs them. If the journal shows it found damage, that comes before everything else.";
    r2-backup = "This job is the copy of {{ $labels.host }}'s data in Cloudflare R2, the one to restore from if the Storage Box is what's gone, so anything newer than its last good run has no copy there.";
    r2-prune = "This job clears old snapshots out of {{ $labels.host }}'s R2 bucket. Nothing is lost while it's stuck, but the bucket keeps growing and the bill with it.";
    r2-check = "This job reads back part of {{ $labels.host }}'s R2 repo to prove it can still be restored. Without it the backups may be fine, but damage stays hidden until a restore needs them. If the journal shows it found damage, that comes before everything else.";
  };

  humanize =
    seconds:
    if seconds >= 2 * 86400 then "${toString (seconds / 86400)}d" else "${toString (seconds / 3600)}h";

  freshness = lib.concatLists (
    lib.mapAttrsToList (task: seconds: [
      {
        alert = "BackupStale";
        expr = ''time() - homelab_backup_last_success_timestamp_seconds{task="${task}"} > ${toString seconds}'';
        labels = {
          severity = "warning";
          inherit task;
        };
        annotations = {
          summary = "{{ $labels.host }}'s last successful restic ${task} was {{ $value | humanizeDuration }} ago";
          condition = "No successful ${task} in ${humanize seconds}";
          description = "${stakes.${task}} The check shows how the last run ended. A stale lock clears with `restic-homelab unlock` or `restic-r2 unlock`, and a network or auth error points at the far end. If nothing has logged lately, a stuck run may be holding the host's restic lock with everything queued behind it, which `systemctl list-units 'restic-backups-*'` shows. `systemctl start restic-backups-${jobs.${task}}` tries again once it's sorted.";
          check = "ssh root@{{ $labels.host }} journalctl -u restic-backups-${jobs.${task}} -n 50";
          dashboard = links.hostBackups "{{ $labels.host }}" task;
        };
      }
      {
        alert = "BackupMissing";
        expr = ''up{job="node", host=~"${lib.concatStringsSep "|" backedUp}"} unless on(host) homelab_backup_last_success_timestamp_seconds{task="${task}"}'';
        for = "${toString seconds}s";
        labels = {
          severity = "warning";
          inherit task;
        };
        annotations = {
          summary = "{{ $labels.host }} has no successful restic ${task} on record";
          condition = "No ${task} on record for ${humanize seconds}";
          description = "${stakes.${task}} {{ $labels.host }} has data to back up and has been up long enough to run this, yet there's no record of it ever finishing. The record is a stamp in `${config.homelab.metricsDir}`, so a rebuilt host loses it even when the repo is fine. The check shows whether the job has run at all, and `systemctl start restic-backups-${jobs.${task}}` runs it now and shows what stops it.";
          check = "ssh root@{{ $labels.host }} journalctl -u restic-backups-${jobs.${task}} -n 50";
          dashboard = links.hostBackups "{{ $labels.host }}" task;
        };
      }
    ]) maxAge
  );
in
{
  homelab.secrets = [ "hetzner-api-token" ];

  systemd.services.storagebox-usage = {
    path = [
      pkgs.curl
      pkgs.jq
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -o pipefail
      curl -sSf -H "Authorization: Bearer $(< ${config.age.secrets.hetzner-api-token.path})" \
        https://api.hetzner.com/v1/storage_boxes/541366 \
        | jq -r '.storage_box | "homelab_storagebox_used_bytes \(.stats.size)\nhomelab_storagebox_size_bytes \(.storage_box_type.size)"' \
        > ${usageFile}.tmp
      mv ${usageFile}.tmp ${usageFile}
    '';
  };

  systemd.timers.storagebox-usage = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };

  services.prometheus.scrapeConfigs = [
    {
      job_name = "storagebox";
      metrics_path = "/probe";
      params.module = [ "ssh_banner" ];
      static_configs = [ { targets = [ "${box}:23" ]; } ];
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "localhost:9115";
        }
      ];
    }
  ];

  services.prometheus.ruleFiles = [
    (pkgs.writeText "backup.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "backup";
            rules = freshness ++ [
              {
                alert = "StorageBoxUnreachable";
                expr = ''probe_success{job="storagebox"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "The Storage Box isn't answering SFTP, so no host can back up";
                  condition = "SSH banner probe failing for 15m";
                  description = "Every host's backup to the box fails while this lasts, and so do their weekly prunes and checks. The R2 job runs on its own and still gets its copy while the internet is up, so check `r2-backup` is fresh before deciding a night or two costs little. Find out whether it's home or Hetzner: if the internet is out, `docs/internet-down.md` is the place to start, and otherwise it's Hetzner's status page. Run the check from monitoring, since the probe goes over IPv4 from there and a machine with IPv6 can get a different answer.";
                  check = "nc -vz {{ reReplaceAll \":.*\" \"\" $labels.instance }} 23";
                  dashboard = links.backups;
                };
              }
              {
                alert = "StorageBoxFilling";
                expr = "homelab_storagebox_used_bytes / homelab_storagebox_size_bytes > 0.8";
                for = "1h";
                labels.severity = "warning";
                annotations = {
                  summary = "The Storage Box is {{ $value | humanizePercentage }} full";
                  condition = "Over 80% used for 1h";
                  description = "A full box stops every host's backups at once, and restic needs free space even to prune, so this is easier to sort out while there's room. The check shows monitoring's own Sunday prune, which only speaks for that host. A `BackupStale` for a prune on any other host is probably the cause. If there's none, it's real growth, so work out which host's backups grew. Retired services' `<service>-final-archives/` folders are on the box too, and `storage_box_type` in `terraform/hetzner.tf` is the bigger box if it comes to that.";
                  check = "ssh root@monitoring journalctl -u restic-backups-homelab-prune -n 50";
                  dashboard = links.backups;
                };
              }
              {
                alert = "StorageBoxUsageStale";
                expr = ''time() - node_textfile_mtime_seconds{file=~".*storagebox.prom"} > 3 * 3600'';
                labels.severity = "warning";
                annotations = {
                  summary = "Storage Box usage hasn't updated from Hetzner's API in over 3 hours";
                  condition = "Usage file older than 3h";
                  description = "The hourly job on monitoring that asks Hetzner how full the box is has stopped working, so `StorageBoxFilling` is reading an old number and can't warn you. Backups aren't affected. Look for curl's error in the check's output: a 401 or 403 means the `hetzner-api-token` secret needs replacing, and a 5xx or a timeout is Hetzner's end and usually passes.";
                  check = "ssh root@monitoring journalctl -u storagebox-usage -n 20";
                  dashboard = links.backups;
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
