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
      ratio,
      summary,
      check,
    }:
    {
      inherit alert;
      expr = "${ratio} > ${toString value}";
      for = "10m";
      labels.severity = severity;
      annotations = {
        inherit summary check;
        condition = "Over ${toString (builtins.floor (value * 100))}% full for 10m";
      };
    };

  filling =
    {
      name,
      ratio,
      summary,
      check,
    }:
    map (rule: full (rule // { inherit ratio summary check; })) [
      {
        alert = "${name}Filling";
        severity = "warning";
        value = 0.8;
      }
      {
        alert = "${name}AlmostFull";
        severity = "critical";
        value = 0.9;
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
                  check = "ssh {{ $labels.host }} sudo lvs incus";
                }
                ++ filling {
                  name = "IncusThinPoolMetadata";
                  ratio = "homelab_incus_thinpool_metadata_ratio{${hostMatcher}}";
                  summary = "Thin pool {{ $labels.vg }}/{{ $labels.lv }} on {{ $labels.host }} has {{ $value | humanizePercentage }} of its metadata used";
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
