{
  pkgs,
  lib,
  nodes,
  ...
}:
let
  links = import ../grafana/links.nix;
  dnsHosts = lib.filterAttrs (_: node: node.config.services.blocky.enable or false) nodes;
in
{
  services.prometheus.scrapeConfigs = [
    {
      job_name = "blocky";
      static_configs = lib.mapAttrsToList (name: node: {
        targets = [ "${node.config.homelab.lanAddress}:4000" ];
        labels.host = name;
      }) dnsHosts;
    }

    {
      job_name = "dns";
      metrics_path = "/probe";
      params = {
        module = [ "dns" ];
      };
      static_configs = lib.mapAttrsToList (name: node: {
        targets = [ "${node.config.homelab.lanAddress}" ];
        labels.host = name;
      }) dnsHosts;
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
    (pkgs.writeText "blocky.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "dns";
            rules = [
              {
                alert = "DnsNotAnswering";
                expr = ''probe_success{job="dns"} == 0'';
                for = "3m";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.host }} isn't answering DNS";
                  condition = "DNS probe failing for 3m";
                  check = "dig @{{ $labels.instance }} example.com";
                  dashboard = links.dns;
                };
              }
              {
                alert = "DnsLookupsFailing";
                expr = ''
                  (
                    sum by (host) (increase(blocky_error_total[10m]))
                      / sum by (host) (increase(blocky_query_total[10m]))
                    > 0.02
                  )
                  and sum by (host) (increase(blocky_error_total[10m])) >= 10
                '';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }} is failing {{ $value | humanizePercentage }} of DNS lookups";
                  condition = "Over 2% of lookups, and at least 10, failing for 5m";
                  check = "ssh root@{{ $labels.host }} \"journalctl -u blocky --since -15m | grep -c 'no resolver returned'\", then docs/internet-down.md";
                  dashboard = links.dns;
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
