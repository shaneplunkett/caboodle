{ pkgs, ... }:
let
  links = import ../grafana/links.nix;
  check = "ssh root@monitoring journalctl -u unifi-poller -n 50";
  dashboard = links.logs "monitoring" [ "unifi-poller.service" ];
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "unpoller.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "unpoller";
            rules = [
              {
                alert = "UnpollerDown";
                expr = ''up{job="unpoller"} == 0'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "Unpoller isn't answering, so there are no UniFi or WAN metrics";
                  condition = "Unpoller scrape failing for 5m";
                  inherit check dashboard;
                };
              }
              {
                alert = "UnpollerCantReadGateway";
                expr = "unpoller_controller_up == 0";
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "Unpoller can't read the UniFi gateway, so its metrics are going stale";
                  condition = "Gateway poll failing for 5m";
                  inherit check dashboard;
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
