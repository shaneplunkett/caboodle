{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  monitored = lib.filterAttrs (
    _: node: node.config.services.prometheus.exporters.smartctl.enable or false
  ) nodes;
  hostMatcher = ''host=~"${lib.concatStringsSep "|" (lib.attrNames monitored)}"'';
  smartLog = "ssh root@{{ $labels.host }} smartctl -a /dev/disk/by-id/{{ $labels.device }}";

  missingDrives = lib.concatLists (
    lib.mapAttrsToList (
      name: node:
      map (device: {
        alert = "SmartctlDriveMissing";
        expr = ''absent(smartctl_device_smart_status{host="${name}", device="${baseNameOf device}"}) and on(host) (up{job="smartctl"} == 1)'';
        for = "10m";
        labels = {
          severity = "warning";
          host = name;
          device = baseNameOf device;
        };
        annotations = {
          summary = "{{ $labels.device }} on {{ $labels.host }} has no SMART health reading";
          condition = "Exporter is answering but this drive's health reading has been missing for 10m";
          check = smartLog;
        };
      }) node.config.services.prometheus.exporters.smartctl.devices
    ) monitored
  );
in
{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "smartctl";
        scrape_timeout = "30s";
        static_configs = lib.mapAttrsToList (name: node: {
          targets = [
            "${node.config.homelab.lanAddress}:${toString node.config.services.prometheus.exporters.smartctl.port}"
          ];
          labels.host = name;
        }) monitored;
      }
    ];

    ruleFiles = [
      (pkgs.writeText "smartctl.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "smartctl";
              rules = [
                {
                  alert = "SmartctlExporterDown";
                  expr = ''up{job="smartctl"} == 0'';
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "SMART monitoring on {{ $labels.host }} isn't answering";
                    condition = "SMART exporter unreachable for 5m";
                    check = "ssh root@{{ $labels.host }} journalctl -u prometheus-smartctl-exporter -n 50";
                  };
                }
                {
                  alert = "SmartctlReadFailed";
                  expr = "smartctl_device_smartctl_exit_status{${hostMatcher}} % 8 > 0";
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} cannot be read by smartctl";
                    condition = "smartctl reports an invocation, device-open or SMART-command error for 10m";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlHealthFailed";
                  expr = "smartctl_device_smart_status{${hostMatcher}} == 0";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} is failing SMART health checks";
                    condition = "The drive reports a failing SMART status";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlSectorsGrowing";
                  expr = ''delta(smartctl_device_attribute{${hostMatcher}, attribute_value_type="raw", attribute_id="5"}[1d]) > 0'';
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} has more {{ $labels.attribute_name }} sectors";
                    condition = "Reallocated sectors increased in the last day";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlPendingSectors";
                  expr = ''smartctl_device_attribute{${hostMatcher}, attribute_value_type="raw", attribute_id=~"197|198"} > 0'';
                  for = "5m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} has {{ $value }} {{ $labels.attribute_name }} sectors";
                    condition = "Pending or uncorrectable sectors have been present for 5m";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlDriveHot";
                  expr = ''(smartctl_device_temperature{${hostMatcher}, temperature_type="current"} > 50 and on(host, device) smartctl_device{protocol="ATA"}) or (smartctl_device_temperature{${hostMatcher}, temperature_type="current"} > 70 and on(host, device) smartctl_device{protocol="NVMe"})'';
                  for = "10m";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} is at {{ $value }}°C";
                    condition = "ATA drive over 50°C or NVMe over 70°C for 10m";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlCriticalWarning";
                  expr = "smartctl_device_critical_warning{${hostMatcher}} > 0";
                  labels.severity = "critical";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} is raising NVMe critical warning {{ $value }}";
                    condition = "The drive's NVMe critical warning flags are set";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlMediaErrors";
                  expr = "increase(smartctl_device_media_errors{${hostMatcher}}[1d]) > 0";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} logged new NVMe media errors";
                    condition = "NVMe media errors increased in the last day";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlSpareLow";
                  expr = "smartctl_device_available_spare{${hostMatcher}} < 2 * smartctl_device_available_spare_threshold{${hostMatcher}}";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} has {{ $value }}% spare blocks left";
                    condition = "NVMe spare under twice the manufacturer's threshold";
                    check = smartLog;
                  };
                }
                {
                  alert = "SmartctlWearingOut";
                  expr = "smartctl_device_percentage_used{${hostMatcher}} >= 90";
                  labels.severity = "warning";
                  annotations = {
                    summary = "{{ $labels.device }} on {{ $labels.host }} has used {{ $value }}% of its rated endurance";
                    condition = "At least 90% of the manufacturer's rated NVMe endurance used";
                    check = smartLog;
                  };
                }
              ]
              ++ missingDrives;
            }
          ];
        }
      ))
    ];
  };
}
