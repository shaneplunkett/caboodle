{
  lib,
  nodes,
  options,
  pkgs,
  ...
}:
let
  byThreshold = import ../prometheus/thresholds.nix { inherit lib nodes options; } "name";
  links = import ../grafana/links.nix;
  incusHosts = lib.filterAttrs (_: node: node.config.virtualisation.incus.enable or false) nodes;
  poolFull = alert: severity: value: {
    inherit alert;
    expr = "incus_storage_pool_used_bytes / incus_storage_pool_size_bytes > ${toString value}";
    for = "10m";
    labels.severity = severity;
    annotations = {
      summary = "Incus pool {{ $labels.pool }} on {{ $labels.host }} is {{ $value | humanizePercentage }} full";
      condition = "Over ${toString (builtins.floor (value * 100))}% full for 10m";
      check = "ssh {{ $labels.host }} sudo lvs incus";
    };
  };
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
                byThreshold "cpu" (
                  {
                    value,
                    percent,
                    matcher,
                  }:
                  {
                    alert = "GuestCpuHigh";
                    expr = "sum without (cpu, mode) (rate(incus_cpu_seconds_total{${matcher}}[5m])) / incus_cpu_effective_total{${matcher}} > ${toString value}";
                    for = "15m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "{{ $labels.name }} on {{ $labels.host }} is at {{ $value | humanizePercentage }} of its CPUs";
                      condition = "CPU over ${percent} for 15m";
                      check = "ssh {{ $labels.name }} top -bn1 -c | head -20";
                      dashboard = links.hostHealth "{{ $labels.name }}";
                    };
                  }
                )
                ++ [
                  (poolFull "IncusPoolFilling" "warning" 0.8)
                  (poolFull "IncusPoolAlmostFull" "critical" 0.9)
                  {
                    alert = "IncusMetricsDown";
                    expr = ''up{job="incus"} == 0'';
                    for = "5m";
                    labels.severity = "warning";
                    annotations = {
                      summary = "Incus on {{ $labels.host }} isn't serving metrics, so its guest CPU and pool alerts are blind";
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
