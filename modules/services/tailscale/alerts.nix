{ pkgs, ... }:
let
  links = import ../grafana/links.nix;
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "tailscale.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "tailscale";
            rules = [
              {
                alert = "TailscaleDown";
                expr = ''node_systemd_unit_state{name="tailscaled.service", state="active"} == 0'';
                for = "5m";
                labels.severity = "warning";
                annotations = {
                  summary = "tailscaled isn't running on {{ $labels.host }}";
                  condition = "tailscaled inactive for 5m";
                  check = ''ssh root@{{ reReplaceAll ":.*" "" $labels.instance }} journalctl -u tailscaled -n 50'';
                  dashboard = links.logs "{{ $labels.host }}" [ "tailscaled.service" ];
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
