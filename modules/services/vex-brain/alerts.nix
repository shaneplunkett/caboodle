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
                  description = "The Saturday drill restores the latest brain dump into a scratch database and counts what comes back, which is the proof the brain can be restored. The backups may still be fine, but until it passes again nothing is testing them, and the brain can't be rebuilt from git. The check shows how the last run ended. A `pg_restore` error means the dump itself is bad, and the nightly backup is storing bad dumps while the good ones age out, so sort that first. `systemctl start vex-brain-restore-drill` runs it again without waiting for Saturday.";
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
