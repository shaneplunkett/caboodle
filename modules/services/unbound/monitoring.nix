{ lib, nodes, ... }:
let
  dnsHosts = lib.filterAttrs (_: node: node.config.services.unbound.enable or false) nodes;
in
{
  services = {
    prometheus.scrapeConfigs = [
      {
        job_name = "unbound";
        static_configs = lib.mapAttrsToList (name: node: {
          targets = [ "${node.config.homelab.lanAddress}:9167" ];
          labels.host = name;
        }) dnsHosts;
      }
    ];
  };
}
