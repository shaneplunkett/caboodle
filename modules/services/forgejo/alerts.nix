{ pkgs, nodes, ... }:
let
  links = import ../grafana/links.nix;
  forge = nodes.forge.config.services.forgejo.settings.server.ROOT_URL;
  run = ''{{ $value | printf "%.0f" }}'';

  unitDown = alert: unit: what: {
    inherit alert;
    expr = ''node_systemd_unit_state{name="${unit}", state="active", host="forge"} == 0'';
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
    (pkgs.writeText "forgejo.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "forgejo";
            rules = [
              (unitDown "ForgejoDown" "forgejo.service" "Forgejo")
              (unitDown "ForgejoPostgresDown" "postgresql.service" "Forgejo's PostgreSQL")
              {
                alert = "ForgejoWorkflowFailing";
                expr = "homelab_forgejo_workflow_failed_run > 0";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.repo }}'s {{ $labels.workflow }} is failing on {{ $labels.branch }}";
                  condition = "[Run #${run}](${forge}{{ $labels.repo }}/actions/runs/${run}) was the last to finish";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
