{ pkgs, ... }:
let
  links = import ../grafana/links.nix;
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "vex-brain.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "vex-brain";
            rules = [
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
