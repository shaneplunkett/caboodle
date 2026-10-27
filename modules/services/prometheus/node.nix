{
  config,
  nodes,
  lib,
  options,
  pkgs,
  ...
}:
let
  byThreshold = import ./thresholds.nix { inherit lib nodes options; } "host";
  monitored = lib.filterAttrs (_: node: node.config.homelab.monitoring.enable) nodes;
  proxmox = config.homelab.proxmoxNodes;
  links = import ../grafana/links.nix;
  containers = lib.attrNames (lib.filterAttrs (_: node: node.config.boot.isContainer or false) nodes);
in
{
  services.prometheus = {
    ruleFiles = [
      (pkgs.writeText "node.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "node";
              rules = [
                {
                  alert = "HostDown";
                  expr = ''up{job="node"} == 0'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.host }} isn't answering";
                    condition = "Node exporter unreachable for 5m";
                    check = "ssh root@{{ $labels.host }} systemctl status prometheus-node-exporter";
                    dashboard = links.hostHealth "{{ $labels.host }}";
                  };
                }
              ]
              ++ byThreshold "memoryAvailable" (
                {
                  value,
                  percent,
                  matcher,
                }:
                let
                  memory = import ./memory.nix matcher;
                in
                {
                  alert = "HostMemoryLow";
                  expr = "${memory.available} / ${memory.total} < ${toString value}";
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.host }} has only {{ $value | humanizePercentage }} memory free";
                    condition = "Free memory under ${percent} for 10m";
                    check = "ssh {{ $labels.host }} 'ps -eo rss,comm | sort -rn | head'";
                    dashboard = links.hostHealth "{{ $labels.host }}";
                  };
                }
              )
              ++ byThreshold "cpu" (
                {
                  value,
                  percent,
                  matcher,
                }:
                {
                  alert = "HostCpuHigh";
                  expr = ''1 - avg by (host) (rate(node_cpu_seconds_total{mode="idle",host!~"${lib.concatStringsSep "|" containers}",${matcher}}[5m])) > ${toString value}'';
                  for = "15m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.host }} is at {{ $value | humanizePercentage }} CPU";
                    condition = "CPU over ${percent} for 15m";
                    check = "ssh {{ $labels.host }} 'ps -eo pcpu,comm | sort -rn | head'";
                    dashboard = links.hostHealth "{{ $labels.host }}";
                  };
                }
              )
              ++ byThreshold "disk" (
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
        static_configs =
          lib.mapAttrsToList (name: node: {
            targets = [ "${node.config.homelab.lanAddress}:9100" ];
            labels.host = name;
          }) monitored
          ++ lib.mapAttrsToList (name: address: {
            targets = [ "${address}:9100" ];
            labels.host = name;
          }) proxmox;
      }
    ];
  };
}
