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
    (pkgs.writeText "vex-brain.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "vex-brain";
            rules = [
              (unitDown "BrainDown" "vex-brain.service" "The Vex brain")
              (unitDown "BrainPostgresDown" "postgresql.service" "The brain's PostgreSQL")
              (unitDown "BrainTunnelDown" "cloudflared.service" "The brain's Cloudflare tunnel")
              {
                alert = "BrainRestoreDrillStale";
                expr = "time() - vex_brain_restore_drill_last_success_timestamp_seconds > 9 * 86400";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}'s last successful brain restore drill was {{ $value | humanizeDuration }} ago";
                  condition = "No successful restore drill in 9d";
                  check = "ssh root@{{ $labels.host }} journalctl -u vex-brain-restore-drill -n 50";
                  dashboard = links.logs "{{ $labels.host }}" [ "vex-brain-restore-drill.service" ];
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
