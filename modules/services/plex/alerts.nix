{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  links = import ../grafana/links.nix;
  plex = lib.filterAttrs (_: node: node.config.services.plex.enable or false) nodes;
in
{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "plex";
        metrics_path = "/probe";
        params.module = [ "http_2xx" ];
        static_configs = lib.mapAttrsToList (name: node: {
          targets = [ "http://${node.config.homelab.lanAddress}:32400/identity" ];
          labels.host = name;
        }) plex;
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

    ruleFiles = [
      (pkgs.writeText "plex.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "plex";
              rules = [
                {
                  alert = "PlexUnreachable";
                  expr = ''probe_success{job="plex"} == 0'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Plex on {{ $labels.host }} isn't answering, so nobody can watch anything";
                    condition = "Plex's web port failing for 5m";
                    check = "ssh root@{{ $labels.host }} journalctl -u plex -n 50";
                    dashboard = links.logs "{{ $labels.host }}" [ "plex.service" ];
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
