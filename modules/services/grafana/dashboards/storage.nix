{ lib }:
let
  inherit (import ./panels.nix { inherit lib; })
    at
    query
    row
    bars
    usageNow
    overTime
    state
    timeline
    upOrDown
    firing
    labelVariable
    dashboard
    ;

  host = ''host=~"$host"'';
  poolFull = "100 * incus_storage_pool_used_bytes{${host}} / incus_storage_pool_size_bytes{${host}}";
  nasFree = ''node_filesystem_avail_bytes{${host},fstype="xfs",mountpoint=~"/mnt/disk[0-9]+"}'';
  nasBytes = {
    unit = "decbytes";
    min = 0;
    color.mode = "thresholds";
    thresholds = {
      mode = "absolute";
      steps = [
        {
          color = "red";
          value = null;
        }
        {
          color = "green";
          value = 200 * 1000 * 1000 * 1000;
        }
      ];
    };
  };
in
dashboard {
  uid = "storage";
  title = "Storage";

  variables = [ (labelVariable "host" "Host" ''up{job="incus"}'') ];

  panels = [
    (row "Right now" 0)
    (firing (at 0 1 24 5) "{{alertname}} {{host}} {{pool}}{{lv}}{{mountpoint}}" [
      ''alertname=~"Incus.*|NasDiskSpaceLow",${host}''
    ])

    (row "Incus pools" 6)
    (lib.recursiveUpdate (usageNow "Full now" (at 0 7 8 8) "{{host}} {{pool}}" poolFull) {
      options = {
        namePlacement = "top";
        text = {
          titleSize = 13;
          valueSize = 13;
        };
      };
    })
    (overTime {
      title = "Full";
      gridPos = at 8 7 16 8;
      targets = [ (query "{{host}} {{pool}}" poolFull) ];
    })

    (row "Thin pool metadata" 15)
    (overTime {
      title = "Metadata used";
      gridPos = at 0 16 12 8;
      targets = [
        (query "{{host}} {{vg}}/{{lv}}" "100 * homelab_incus_thinpool_metadata_ratio{${host}}")
      ];
    })
    (overTime {
      title = "Age of the reading";
      gridPos = at 12 16 12 8;
      defaults = {
        unit = "s";
        min = 0;
      };
      targets = [
        (query "{{host}}" "time() - homelab_incus_thinpool_collected_timestamp_seconds{${host}}")
      ];
    })

    (row "Are the readings coming in" 24)
    (timeline {
      title = "Incus metrics";
      gridPos = at 0 25 12 5;
      targets = [ (query "{{host}}" ''up{job="incus",${host}}'') ];
      states = upOrDown;
    })
    (timeline {
      title = "Thin pool collector";
      gridPos = at 12 25 12 5;
      targets = [
        (query "{{host}}" ''node_systemd_unit_state{name="incus-thinpool-metrics.service",state="failed",${host}}'')
      ];
      states = [
        (state 0 "Fine" "green")
        (state 1 "Failed" "red")
      ];
    })

    (row "NAS data disks" 30)
    (bars {
      title = "Free now";
      gridPos = at 0 31 8 9;
      defaults = nasBytes;
      targets = [ (query "{{host}} {{mountpoint}}" "sort(${nasFree})") ];
    })
    (overTime {
      title = "Free";
      gridPos = at 8 31 16 9;
      defaults = removeAttrs nasBytes [ "color" ];
      targets = [ (query "{{host}} {{mountpoint}}" nasFree) ];
    })
  ];
}
