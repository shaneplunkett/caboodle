{
  lib,
  proxmox,
  incus,
}:
let
  inherit (import ./panels.nix { inherit lib; })
    prometheus
    at
    query
    percent
    byRefId
    plainNumber
    row
    usageNow
    stat
    overTime
    dashboard
    ;

  hypervisors = proxmox ++ lib.attrNames incus;
  notIncusGuest = ''host!~"${lib.concatStringsSep "|" (lib.concatLists (lib.attrValues incus))}"'';
  containers = ''job="node",host!~"${lib.concatStringsSep "|" hypervisors}"'';
  guestStorage = "local-lvm";

  physicalNics = ''device=~"eth.*|en.*"'';
  realFilesystems = ''fstype=~"ext4|xfs|btrfs|zfs|vfat|nfs4",mountpoint!="/nix/store"'';

  cpuUsed =
    selector: window:
    ''100 * (1 - avg by (host) (rate(node_cpu_seconds_total{${selector},mode="idle"}[${window}])))'';
  guestCpuUsed =
    selector: "100 * pve_cpu_usage_ratio * on (id) group_left (name) pve_guest_info{${selector}}";
  incusCpuUsed =
    selector:
    "100 * sum without (cpu, mode) (rate(incus_cpu_seconds_total{${selector}}[$__rate_interval])) / incus_cpu_effective_total{${selector}}";
  byName = expr: ''label_replace(${expr}, "host", "$1", "name", "(.*)")'';
  containerCpuUsed = "${byName (guestCpuUsed lxc)} or on (host) ${byName (incusCpuUsed ''job="incus"'')} or on (host) ${cpuUsed "${containers},${notIncusGuest}" "$__rate_interval"}";
  memory = import ../../prometheus/memory.nix;
  memoryUsed =
    selector:
    let
      inherit (memory selector) available total;
    in
    "100 * (1 - ${available} / ${total})";
  rootUsed =
    selector:
    ''100 * (1 - node_filesystem_avail_bytes{${selector},mountpoint="/"} / node_filesystem_size_bytes{${selector},mountpoint="/"})'';
  traffic =
    direction: selector:
    "rate(node_network_${direction}_bytes_total{${selector},${physicalNics}}[$__rate_interval])";

  hypervisorCard =
    x: name:
    let
      node = ''host="${name}"'';
      storage = ''id="storage/${name}/${guestStorage}"'';
      guests =
        if incus ? ${name} then
          [
            (query "Root disk" (rootUsed node))
            (query "Guests up" ''count(up{job="node",host=~"${
              lib.concatStringsSep "|" incus.${name}
            }"} == 1) or vector(0)'')
          ]
        else
          [
            (query "Guest storage" "100 * pve_disk_usage_bytes{${storage}} / pve_disk_size_bytes{${storage}}")
            (query "Guests up" ''count(pve_up * on (id) group_right () pve_guest_info{node="${name}"} == 1) or vector(0)'')
          ];
    in
    stat {
      title = name;
      gridPos = at x 1 12 5;
      sparkline = true;
      targets = [
        (query "CPU" (cpuUsed node "$__rate_interval"))
        (query "Memory" (memoryUsed node))
      ]
      ++ guests;
      defaults = removeAttrs percent [ "max" ];
      overrides = [ (byRefId "D" plainNumber) ];
    };

  host = ''host="$host"'';
  hostMemory = memory host;
  lxc = ''type="lxc"'';
  guest = ''name="$host"'';
in
dashboard {
  uid = "hosts";
  title = "Host health";

  variables = [
    {
      name = "host";
      label = "Host";
      type = "query";
      datasource = prometheus;
      query = {
        qryType = 1;
        query = ''label_values(up{job="node"}, host)'';
        refId = "hosts";
      };
      definition = ''label_values(up{job="node"}, host)'';
      refresh = 1;
      sort = 1;
    }
  ];

  panels = [
    (row "Hypervisors" 0)
  ]
  ++ lib.imap0 (i: hypervisorCard (i * 12)) hypervisors
  ++ [
    (row "Containers" 6)
    (usageNow "CPU now" (at 0 7 8 11) "{{host}}" containerCpuUsed)
    (usageNow "Memory now" (at 8 7 8 11) "{{host}}" (memoryUsed containers))
    (usageNow "Root disk now" (at 16 7 8 11) "{{host}}" (rootUsed containers))
    (overTime {
      title = "CPU";
      gridPos = at 0 18 12 9;
      targets = [ (query "{{host}}" containerCpuUsed) ];
    })
    (overTime {
      title = "Memory";
      gridPos = at 12 18 12 9;
      targets = [ (query "{{host}}" (memoryUsed containers)) ];
    })
    (overTime {
      title = "Root disk";
      gridPos = at 0 27 12 9;
      targets = [ (query "{{host}}" (rootUsed containers)) ];
    })
    (overTime {
      title = "Network";
      gridPos = at 12 27 12 9;
      defaults.unit = "Bps";
      targets = [
        (query "{{host}}" "sum by (host) (${traffic "receive" containers} + ${traffic "transmit" containers})")
      ];
    })

    (row "$host" 36)
    (overTime {
      title = "CPU";
      gridPos = at 0 37 12 9;
      stacked = true;
      defaults = removeAttrs percent [ "max" ];
      targets = [
        (query "used" (guestCpuUsed guest))
        (query "used" (incusCpuUsed guest))
        (query "{{mode}}" ''100 * avg by (mode) (rate(node_cpu_seconds_total{${host},${notIncusGuest},mode!="idle"}[$__rate_interval])) unless on () pve_guest_info{${guest}}'')
      ];
    })
    (overTime {
      title = "Memory";
      gridPos = at 12 37 12 9;
      stacked = true;
      defaults.unit = "bytes";
      targets = [
        (query "Used" "${hostMemory.total} - ${hostMemory.available}")
        (query "Available" hostMemory.available)
      ];
    })
    (usageNow "Filesystems" (at 0 46 12 9) "{{mountpoint}}"
      "100 * (1 - node_filesystem_avail_bytes{${host},${realFilesystems}} / node_filesystem_size_bytes{${host},${realFilesystems}})"
    )
    (overTime {
      title = "Network";
      gridPos = at 12 46 12 9;
      defaults.unit = "Bps";
      targets = [
        (query "{{device}} in" "sum by (device) (${traffic "receive" host})")
        (query "{{device}} out" "-sum by (device) (${traffic "transmit" host})")
      ];
    })
  ];
}
