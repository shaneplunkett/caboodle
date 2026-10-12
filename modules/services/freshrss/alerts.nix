{ pkgs, ... }:
let
  links = import ../grafana/links.nix;
  unitDown = alert: unit: what: {
    inherit alert;
    expr = ''node_systemd_unit_state{name="${unit}", state="active"} == 0'';
    for = "5m";
    labels.severity = "critical";
    annotations = {
      summary = "${what} isn't running on {{ $labels.host }}";
      condition = "${unit} inactive for 5m";
      check = "ssh root@{{ $labels.host }} journalctl -u ${unit} -n 50";
      dashboard = links.logs "{{ $labels.host }}" [ unit ];
    };
  };
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "freshrss.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "freshrss";
            rules = [
              (unitDown "FreshRSSDown" "phpfpm-freshrss.service" "FreshRSS")
              (unitDown "FreshRSSNginxDown" "nginx.service" "FreshRSS's nginx")
              {
                alert = "FreshRSSNotUpdating";
                expr = ''node_systemd_unit_state{name="freshrss-updater.service", state="failed"} == 1'';
                for = "30m";
                labels.severity = "warning";
                annotations = {
                  summary = "FreshRSS has stopped fetching feeds on {{ $labels.host }}";
                  condition = "freshrss-updater.service failed for 30m";
                  check = "ssh root@{{ $labels.host }} journalctl -u freshrss-updater -n 50";
                  dashboard = links.logs "{{ $labels.host }}" [ "freshrss-updater.service" ];
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
