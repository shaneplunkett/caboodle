{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  monitored = lib.filterAttrs (_: node: node.config.homelab ? nas) nodes;
  hostMatcher = ''host=~"${lib.concatStringsSep "|" (lib.attrNames monitored)}"'';
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "nas.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "nas";
            rules = [
              {
                alert = "NasDiskSpaceLow";
                expr = ''node_filesystem_avail_bytes{${hostMatcher}, fstype="xfs", mountpoint=~"/mnt/disk[0-9]+"} < 200 * 1000 * 1000 * 1000'';
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.mountpoint }} on {{ $labels.host }} has {{ $value | humanize }}B free";
                  condition = "Less than 200 GB free on this data disk for 10m";
                  check = "ssh root@{{ $labels.host }} df -h {{ $labels.mountpoint }}";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
