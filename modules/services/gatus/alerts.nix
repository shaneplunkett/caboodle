{ pkgs, nodes, ... }:
let
  links = import ../grafana/links.nix;
in
{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "gatus";
        static_configs = [ { targets = [ "${nodes.dashboard.config.homelab.lanAddress}:8082" ]; } ];
      }
    ];

    ruleFiles = [
      (pkgs.writeText "gatus.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "gatus";
              rules = [
                {
                  alert = "EndpointDown";
                  expr = "gatus_results_endpoint_success == 0";
                  for = "3m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.group }}/{{ $labels.name }} is failing its Gatus checks";
                    condition = "Gatus check failing for 3m";
                    check = ''curl -s https://status.shaneplunkett.com/api/v1/endpoints/{{ reReplaceAll "[ /_,.#+&]" "-" ($labels.group | toLower) }}_{{ reReplaceAll "[ /_,.#+&]" "-" ($labels.name | toLower) }}/statuses | jq ".results[-1].conditionResults"'';
                  };
                }
                {
                  alert = "GatusDown";
                  expr = ''up{job="gatus"} == 0'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "Gatus on the dashboard host isn't answering, so PVE or the dashboard box may be down";
                    condition = "Gatus metrics unreachable for 5m";
                    check = "ssh root@dashboard systemctl status gatus";
                    dashboard = links.logs "dashboard" [ "gatus.service" ];
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
