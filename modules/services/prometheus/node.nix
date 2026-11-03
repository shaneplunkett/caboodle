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
                    description = "When a root disk runs out, things break in a messy order: services fail their writes, databases stop, the journal goes quiet, and Nix can't switch, so the next deploy fails too. There's still room, but nothing here says how fast it's going, so look today. The check lists the biggest folders. A huge `/var/log/journal` or `/nix/store` is housekeeping that's fallen behind, and a service's folder under `/var/lib` is real growth. A guest takes more room by raising `disk` in its `homelab.guest`, merging, then `scripts/terraform.sh apply` from the desktop, since a merge only runs Terraform when `terraform/` changed. The cache guest is the exception: it has no `disk` on purpose, and `docs/pve/cache.md` says why.";
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
