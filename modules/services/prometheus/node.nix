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
                {
                  alert = "HostMemoryLow";
                  expr = "node_memory_MemAvailable_bytes{${matcher}} / node_memory_MemTotal_bytes < ${toString value}";
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.host }} has only {{ $value | humanizePercentage }} memory free";
                    condition = "Free memory under ${percent} for 10m";
                    check = "ssh root@{{ $labels.host }} ps aux --sort=-rss | head";
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
