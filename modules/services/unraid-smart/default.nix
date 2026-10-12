{
  config,
  pkgs,
  ...
}:
let
  unraid = config.homelab.devices.unraid.ip;
  file = "${config.homelab.metricsDir}/unraid-smart.prom";
  device = "{{ $labels.device }} ({{ $labels.model }} {{ $labels.serial }})";
  withInfo = expr: "(${expr}) * on(device) group_left(model, serial) unraid_disk_info";
  smartctl = "ssh root@${unraid} smartctl -a {{ $labels.device }}";
in
{
  homelab.secrets = [ "unraid-smart-ssh-key" ];

  programs.ssh.knownHosts.unraid = {
    hostNames = [ unraid ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICG29U7eHjrq8mWoJpyhpftyNNuvvnnBNTu/5PR4U879";
  };

  systemd.services.unraid-smart = {
    path = [
      pkgs.openssh
      pkgs.jq
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -o pipefail
      ssh -i ${config.age.secrets.unraid-smart-ssh-key.path} -o BatchMode=yes root@${unraid} \
        | jq -r -f ${./smart.jq} | sort > ${file}.tmp
      mv ${file}.tmp ${file}
    '';
  };

  systemd.timers.unraid-smart = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/15";
      Persistent = true;
    };
  };

  services.prometheus.ruleFiles = [
    (pkgs.writeText "unraid-smart.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "unraid-smart";
            rules = [
              {
                alert = "UnraidDiskSmartFailed";
                expr = withInfo "unraid_disk_smart_passed == 0";
                labels.severity = "critical";
                annotations = {
                  summary = "${device} on Unraid is failing its SMART health check";
                  condition = "SMART overall health check failed";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidDiskSectorsWorsening";
                expr = withInfo "delta(unraid_disk_ata_attribute_raw[1d]) > 0";
                labels.severity = "warning";
                annotations = {
                  summary = ''{{ $labels.attribute }} on ${device} went up by {{ $value | printf "%.0f" }} today'';
                  condition = "Bad-sector counter rose in the last day";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidDiskCriticalWarning";
                expr = withInfo "unraid_disk_nvme_critical_warning > 0";
                labels.severity = "critical";
                annotations = {
                  summary = "${device} on Unraid is raising NVMe critical warning {{ $value }}";
                  condition = "The drive's critical warning flags are set";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidDiskMediaErrors";
                expr = withInfo "increase(unraid_disk_nvme_media_errors_total[1d]) > 0";
                labels.severity = "warning";
                annotations = {
                  summary = ''${device} on Unraid logged {{ $value | printf "%.0f" }} new media errors'';
                  condition = "Media errors went up in the last day";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidDiskSpareLow";
                expr = withInfo "unraid_disk_nvme_available_spare_ratio < 2 * unraid_disk_nvme_available_spare_threshold_ratio";
                labels.severity = "warning";
                annotations = {
                  summary = "${device} on Unraid has {{ $value | humanizePercentage }} spare blocks left";
                  condition = "Spare under twice the manufacturer's threshold";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidDiskWearingOut";
                expr = withInfo "unraid_disk_nvme_percentage_used_ratio >= 0.9";
                labels.severity = "warning";
                annotations = {
                  summary = "${device} on Unraid has used {{ $value | humanizePercentage }} of its rated endurance";
                  condition = "Over 90% of the manufacturer's rated endurance used";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidDiskTooHot";
                expr = withInfo "unraid_disk_temperature_celsius > unraid_disk_temperature_limit_celsius or (unraid_disk_temperature_celsius > 55 unless on(device) unraid_disk_temperature_limit_celsius)";
                for = "10m";
                labels.severity = "warning";
                annotations = {
                  summary = "${device} on Unraid is at {{ $value }}°C";
                  condition = "Over the drive's own temperature limit, or 55°C if it doesn't report one, for 10m";
                  check = smartctl;
                };
              }
              {
                alert = "UnraidSmartStale";
                expr = ''time() - node_textfile_mtime_seconds{file=~".*unraid-smart.prom"} > 3600'';
                labels.severity = "warning";
                annotations = {
                  summary = "Unraid's disk health readings are {{ $value | humanizeDuration }} old";
                  condition = "No SMART readings from Unraid for over 1h";
                  check = "ssh root@{{ $labels.host }} journalctl -u unraid-smart -n 50";
                };
              }
            ];
          }
        ];
      }
    ))
  ];
}
