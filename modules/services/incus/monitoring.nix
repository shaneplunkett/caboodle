{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  incusHosts = lib.filterAttrs (
    _: node: node.config.homelab.monitoring.enable && node.config.virtualisation.incus.enable or false
  ) nodes;
  hostMatcher = ''host=~"${lib.concatStringsSep "|" (lib.attrNames incusHosts)}"'';
  collector = "incus-thinpool-metrics";

  full =
    {
      alert,
      severity,
      value,
      urgency,
      ratio,
      summary,
      description,
      check,
      ...
    }:
    {
      inherit alert;
      expr = "${ratio} > ${toString value}";
      for = "10m";
      labels.severity = severity;
      annotations = {
        inherit summary check;
        condition = "Over ${toString (builtins.floor (value * 100))}% full for 10m";
        description = "${description} ${urgency}";
      };
    };

  filling =
    { name, ... }@shared:
    map (rule: full (shared // rule)) [
      {
        alert = "${name}Filling";
        severity = "warning";
        value = 0.8;
        urgency = "There's room for now, so this is a job for this week.";
      }
      {
        alert = "${name}AlmostFull";
        severity = "critical";
        value = 0.9;
        urgency = "It's close now, so this goes ahead of whatever else is on today.";
      }
    ];

  missingPools = lib.concatLists (
    lib.mapAttrsToList (
      host: node:
      map (
        { name, ... }:
        let
          series = metric: ''${metric}{host="${host}", pool="${name}"}'';
        in
        {
          alert = "IncusPoolMetricsMissing";
          expr = ''(absent(${series "incus_storage_pool_used_bytes"}) or absent(${series "incus_storage_pool_size_bytes"})) and on(host) (up{job="incus"} == 1)'';
          for = "10m";
          labels = {
            severity = "warning";
            inherit host;
            pool = name;
          };
          annotations = {
            summary = "Incus on {{ $labels.host }} is answering but not reporting pool {{ $labels.pool }}, so its fill alerts are blind";
            condition = "Scrape up but the pool's size or used bytes missing for 10m";
            description = "Incus leaves a pool out of its metrics when it can't read it, while the scrape still looks healthy, so nothing is watching how full {{ $labels.pool }} is. That failed read can be the real problem: a dead drive or a lost mount under the pool. Look for storage errors in the journal, and `incus storage list` on {{ $labels.host }} shows the pool's state. For `nas-cache`, start with whether `/mnt/cache` is mounted.";
            check = "ssh {{ $labels.host }} sudo journalctl -u incus -n 50";
          };
        }
      ) node.config.virtualisation.incus.preseed.storage_pools
    ) incusHosts
  );
in
{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "incus";
        scheme = "https";
        metrics_path = "/1.0/metrics";
        tls_config.insecure_skip_verify = true;
        static_configs = lib.mapAttrsToList (name: node: {
          targets = [
            "${node.config.homelab.lanAddress}${
              node.config.virtualisation.incus.preseed.config."core.https_address"
            }"
          ];
          labels.host = name;
        }) incusHosts;
      }
    ];

    ruleFiles = [
      (pkgs.writeText "incus.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "incus";
              rules =
                filling {
                  name = "IncusPool";
                  ratio = "incus_storage_pool_used_bytes / incus_storage_pool_size_bytes";
                  summary = "Incus pool {{ $labels.pool }} on {{ $labels.host }} is {{ $value | humanizePercentage }} full";
                  description = "The guests on {{ $labels.host }} write into this pool, and when it runs out their writes fail all at once, databases included. The check lists each guest's volume, so find the one that has grown and clean up inside it. The volume group already takes the rest of the drive, so clean-up is the way out rather than growing the pool. `nas-cache` isn't in that list: it's the btrfs NAS cache, shared with NAS files waiting for the mover, so read `df -h /mnt/cache` and see whether last night's `nas-mover` ran.";
                  check = "ssh {{ $labels.host }} sudo lvs incus";
                }
                ++ filling {
                  name = "IncusThinPoolMetadata";
                  ratio = "homelab_incus_thinpool_metadata_ratio{${hostMatcher}}";
                  summary = "Thin pool {{ $labels.vg }}/{{ $labels.lv }} on {{ $labels.host }} has {{ $value | humanizePercentage }} of its metadata used";
                  description = "Metadata is the pool's own record of which block belongs to which guest, and it can fill before the data does. When it's full the pool stops taking writes for every guest on {{ $labels.host }}, and getting it back can take a repair, which is much worse than running out of space. `vgs {{ $labels.vg }}` shows whether there's free space to grow it with `lvextend --poolmetadatasize +1G {{ $labels.vg }}/{{ $labels.lv }}`. If there isn't, cutting guest data brings the metadata down too.";
                  check = "ssh {{ $labels.host }} sudo lvs -o lv_name,data_percent,metadata_percent {{ $labels.vg }}";
                }
                ++ missingPools
                ++ [
                  {
                    alert = "IncusThinPoolMetricsFailing";
                    expr = ''node_systemd_unit_state{name="${collector}.service", state="failed", ${hostMatcher}} == 1'';
                    for = "5m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "{{ $labels.host }} can't read its thin pool with lvs, so its metadata alerts are blind";
                      condition = "${collector}.service failed for 5m";
                      description = "This job reads the thin pool's metadata with `lvs` every minute, because Incus doesn't report it. With it failing, nothing is watching that metadata, and a full one breaks the pool just as surely as running out of space. A reading bug is dull, but `lvs` itself erroring can mean the volume group is in trouble, so that's what the journal needs to rule out. `no thin pool in incus` means the pool has gone, and LVM or I/O errors mean look at the drive next.";
                      check = "ssh {{ $labels.host }} sudo journalctl -u ${collector} -n 20";
                    };
                  }
                  {
                    alert = "IncusThinPoolMetricsStale";
                    expr = ''time() - homelab_incus_thinpool_collected_timestamp_seconds{${hostMatcher}} > 600 unless on(host) node_systemd_unit_state{name="${collector}.service", state="failed"} == 1'';
                    labels.severity = "warning";
                    annotations = {
                      summary = "{{ $labels.host }}'s thin pool reading is {{ $value | humanizeDuration }} old";
                      condition = "Thin pool metrics older than 10m without the collector failing";
                      description = "The job that reads the thin pool with `lvs` isn't failing, it just isn't finishing, so the metadata number the alerts read has frozen. Either its timer has stopped or `lvs` is hanging, and a hanging `lvs` points at a stuck disk underneath. The check shows when it last ran. If the timer looks fine, `systemctl status ${collector}` shows a run that's stuck, and `journalctl -k` on {{ $labels.host }} shows any disk errors.";
                      check = "ssh {{ $labels.host }} systemctl list-timers ${collector}";
                    };
                  }
                  {
                    alert = "IncusThinPoolMetricsMissing";
                    expr = ''up{job="node", ${hostMatcher}} == 1 unless on(host) homelab_incus_thinpool_collected_timestamp_seconds'';
                    for = "10m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "{{ $labels.host }} has never published its thin pool reading";
                      condition = "Node exporter up but no thin pool metrics for 10m";
                      description = "Node exporter is fine, but the job that reads the thin pool's metadata has written nothing, so the metadata alerts have nothing to read. The likely cause is a rule that reached monitoring on a merge while {{ $labels.host }} hasn't been switched, because PVE and Cube are switched by hand. If the check says the unit doesn't exist, switching the host fixes it. If the unit's there, its status says why it hasn't written.";
                      check = "ssh {{ $labels.host }} systemctl status ${collector}";
                    };
                  }
                  {
                    alert = "IncusMetricsDown";
                    expr = ''up{job="incus"} == 0'';
                    for = "5m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "Incus on {{ $labels.host }} isn't serving metrics, so its pool alerts are blind";
                      condition = "Incus metrics scrape failing for 5m";
                      description = "Prometheus can't scrape Incus on {{ $labels.host }}, so nothing is watching how full its pools are, and the guests' CPU graphs stop too. Either the daemon is down or the metrics endpoint has started asking for a certificate. The check prints `false` when the endpoint is set right, and anything else is why the scrape fails. If the command errors, the daemon is down and `systemctl status incus` shows why. The guests may still be running, but Terraform can't reach them until it's back.";
                      check = "ssh {{ $labels.host }} incus config get core.metrics_authentication";
                    };
                  }
                ];
            }
          ];
        }
      ))
    ];
  };
}
