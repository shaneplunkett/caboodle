{
  lib,
  nodes,
  options,
  pkgs,
  ...
}:
let
  byThreshold = import ../prometheus/thresholds.nix { inherit lib nodes options; } "name";

  criticalGuests = [ "plex" ];

  links = import ../grafana/links.nix;

  percent = value: "${toString (builtins.floor (value * 100 + 0.5))}%";

  storages = [
    {
      type = "lvmthin";
      by = "node, storage";
      where = "{{ $labels.storage }} on {{ $labels.node }}";
      warning = 0.8;
      critical = 0.9;
      check = "ssh {{ $labels.node }} sudo lvs";
    }
    {
      type = "dir";
      by = "node, storage";
      where = "{{ $labels.storage }} on {{ $labels.node }}";
      warning = 0.85;
      critical = 0.95;
      check = "ssh {{ $labels.node }} sudo du -xh -d2 / | sort -h | tail";
    }
    {
      type = "nfs";
      by = "storage";
      where = "the NAS's {{ $labels.storage }} share";
      warning = null;
      critical = 0.98;
      check = "ssh cube df -h /mnt/pve/{{ $labels.storage }}";
    }
  ];

  usage = "max without (instance) (pve_disk_usage_bytes)";
  week = "7d:1h";
  minimumHours = 72;

  perStorage =
    s: expr:
    ''max by (${s.by}) ((${expr}) * on(id) group_left(node, storage) pve_storage_info{plugintype="${s.type}"})'';

  full = s: alert: severity: value: {
    inherit alert;
    expr = "${perStorage s "pve_disk_usage_bytes / pve_disk_size_bytes"} > ${toString value}";
    for = "10m";
    labels = {
      inherit severity;
      storage_type = s.type;
    };
    annotations = {
      summary = "${s.where} is {{ $value | humanizePercentage }} full";
      condition = "Over ${percent value} full for 10m";
      inherit (s) check;
    };
  };

  storageRules =
    s:
    lib.optional (s.warning != null) (full s "StorageFilling" "warning" s.warning)
    ++ [
      (full s "StorageAlmostFull" "critical" s.critical)
      {
        alert = "StorageRunningOut";
        expr = "${perStorage s "max without (instance) (pve_disk_size_bytes - pve_disk_usage_bytes) / (deriv((${usage})[${week}]) > 0) and on(id) count_over_time((${usage})[${week}]) >= ${toString minimumHours}"} < 14 * 86400";
        for = "1h";
        labels = {
          severity = "warning";
          storage_type = s.type;
        };
        annotations = {
          summary = "${s.where} fills up in {{ $value | humanizeDuration }} at this week's rate";
          condition = "Projected full within 14d for 1h, from at least ${toString minimumHours}h of history";
          inherit (s) check;
        };
      }
    ];
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "pve.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "pve";
            rules =
              byThreshold "cpu" (
                {
                  value,
                  percent,
                  matcher,
                }:
                {
                  alert = "GuestCpuHigh";
                  expr = "pve_cpu_usage_ratio * on(id) group_left(name, node) pve_guest_info{${matcher}} > ${toString value}";
                  for = "15m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.name }} on {{ $labels.node }} is at {{ $value | humanizePercentage }} CPU";
                    condition = "CPU over ${percent} for 15m";
                    check = "ssh {{ $labels.node }} top -bn1 -c | head -20";
                    dashboard = links.hostHealth "{{ $labels.name }}";
                  };
                }
              )
              ++ lib.concatMap storageRules storages
              ++ [
                {
                  alert = "CriticalGuestDown";
                  expr = ''pve_up * on(id) group_left(name, node) pve_guest_info{name=~"${lib.concatStringsSep "|" criticalGuests}"} == 0'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.name }} on {{ $labels.node }} isn't running";
                    condition = "Guest stopped for 5m";
                    check = "ssh {{ $labels.node }} sudo pvesh get /nodes/{{ $labels.node }}/{{ $labels.id }}/status/current";
                    dashboard = links.hostHealth "{{ $labels.name }}";
                  };
                }
                {
                  alert = "PveExporterDown";
                  expr = ''up{job="pve"} == 0'';
                  for = "5m";
                  labels.severity = "critical";
                  annotations = {
                    summary = "The Proxmox exporter isn't answering, so guest and storage alerts are blind";
                    condition = "PVE exporter scrape failing for 5m";
                    check = "ssh root@monitoring journalctl -u prometheus-pve-exporter -n 50";
                    dashboard = links.logs "monitoring" [ "prometheus-pve-exporter.service" ];
                  };
                }
              ];
          }
        ];
      }
    ))
  ];
}
