{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  links = import ../grafana/links.nix;
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
                  description = "mergerfs stops putting new files on a disk once it's under 100 GB, so this one is close to dropping out of the pool for new files. The mover sends files to whichever disk has the most room, so they all fall together, and one getting here means the rest are probably close. `df -h /mnt/disk*` on {{ $labels.host }} shows which. If it's only this disk, nothing needs doing. If they're all low, the pool is nearly full and the NVMe cache starts backing up behind it, so clear out the library or plan a bigger drive.";
                  check = "ssh root@{{ $labels.host }} df -h {{ $labels.mountpoint }}";
                  dashboard = links.storage "{{ $labels.host }}";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
