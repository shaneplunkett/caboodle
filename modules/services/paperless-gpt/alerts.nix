{ pkgs, ... }:
let
  links = import ../grafana/links.nix;
  unit = "paperless-gpt.service";
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "paperless-gpt.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "paperless-gpt";
            rules = [
              {
                alert = "PaperlessGptDown";
                expr = ''node_systemd_unit_state{name="${unit}", state="active"} == 0'';
                for = "15m";
                labels.severity = "warning";
                annotations = {
                  summary = "paperless-gpt isn't running on {{ $labels.host }}";
                  condition = "${unit} inactive for 15m";
                  check = "ssh root@{{ $labels.host }} journalctl -u ${unit} -n 50";
                  dashboard = links.logs "{{ $labels.host }}" [ unit ];
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
