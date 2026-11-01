{ lib, nodes, ... }:
let
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
}
