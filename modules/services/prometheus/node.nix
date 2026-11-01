{
  nodes,
  lib,
  options,
  pkgs,
  ...
}:
let
  byThreshold = import ./thresholds.nix { inherit lib nodes options; } "host";
  monitored = lib.filterAttrs (_: node: node.config.homelab.monitoring.enable) nodes;
  links = import ../grafana/links.nix;
in
{
  services.prometheus = {
    ruleFiles = [
      (pkgs.writeText "node.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "node";
              rules = byThreshold "disk" (
                {
                  value,
                  percent,
                  matcher,
                }:
                let
                  root = metric: ''node_filesystem_${metric}_bytes{mountpoint="/",${matcher}}'';
                in
                {
                  alert = "HostDiskFilling";
                  expr = "1 - ${root "avail"} / ${root "size"} > ${toString value}";
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.host }}'s root disk is {{ $value | humanizePercentage }} full";
                    condition = "Root disk over ${percent} for 10m";
                    check = "ssh {{ $labels.host }} sudo du -xh -d2 / | sort -h | tail";
                    dashboard = links.hostHealth "{{ $labels.host }}";
                  };
                }
              );
            }
          ];
        }
      ))
    ];

    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = lib.mapAttrsToList (name: node: {
          targets = [ "${node.config.homelab.lanAddress}:9100" ];
          labels.host = name;
        }) monitored;
      }
    ];
  };
}
