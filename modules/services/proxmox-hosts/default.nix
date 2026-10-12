{
  config,
  lib,
  pkgs,
  ...
}:
let
  hosts = ''host=~"${lib.concatStringsSep "|" (lib.attrNames config.homelab.proxmoxNodes)}"'';
  smartLog = "ssh {{ $labels.host }} sudo nvme smart-log /dev/{{ $labels.device }}";
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "proxmox-hosts.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "proxmox-hosts";
            rules = [
              {
                alert = "DiskCriticalWarning";
                expr = "nvme_critical_warning{${hosts}} > 0";
                labels.severity = "critical";
                annotations = {
                  summary = "{{ $labels.device }} on {{ $labels.host }} is raising NVMe critical warning {{ $value }}";
                  condition = "The drive's critical warning flags are set";
                  check = smartLog;
                };
              }
              {
                alert = "DiskMediaErrors";
                expr = "increase(nvme_media_errors_total{${hosts}}[1d]) > 0";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.device }} on {{ $labels.host }} logged {{ $value | printf \"%.0f\" }} new media errors";
                  condition = "Media errors went up in the last day";
                  check = smartLog;
                };
              }
              {
                alert = "DiskSpareLow";
                expr = "nvme_available_spare_ratio{${hosts}} < 2 * nvme_available_spare_threshold_ratio{${hosts}}";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.device }} on {{ $labels.host }} has {{ $value | humanizePercentage }} spare blocks left";
                  condition = "Spare under twice the manufacturer's threshold";
                  check = smartLog;
                };
              }
              {
                alert = "DiskWearingOut";
                expr = "nvme_percentage_used_ratio{${hosts}} >= 0.9";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.device }} on {{ $labels.host }} has used {{ $value | humanizePercentage }} of its rated endurance";
                  condition = "Over 90% of the manufacturer's rated endurance used";
                  check = smartLog;
                };
              }
              {
                alert = "DiskHealthStale";
                expr = ''time() - node_textfile_mtime_seconds{${hosts}, file=~".*nvme.prom"} > 3600'';
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.host }}'s NVMe health readings are {{ $value | humanizeDuration }} old";
                  condition = "No NVMe readings for over 1h";
                  check = "ssh {{ $labels.host }} systemctl status prometheus-node-exporter-nvme.service";
                };
              }
              {
                alert = "HardwareTooHot";
                expr = "node_hwmon_temp_celsius{${hosts}} > node_hwmon_temp_crit_celsius{${hosts}} - 5";
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "{{ $labels.chip }} {{ $labels.sensor }} on {{ $labels.host }} is at {{ $value }}°C";
                  condition = "Within 5°C of its critical temperature for 10m";
                  check = "ssh {{ $labels.host }} grep . /sys/class/hwmon/*/name /sys/class/hwmon/*/temp*_input";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
