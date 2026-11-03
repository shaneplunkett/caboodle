{ lib }:
let
  inherit (import ./panels.nix { inherit lib; })
    at
    query
    percent
    row
    overTime
    state
    timeline
    upOrDown
    firing
    labelVariable
    dashboard
    ;

  selected = ''host=~"$host",device=~"$device"'';
  count = {
    unit = "short";
    decimals = 0;
    min = 0;
  };
in
dashboard {
  uid = "disks";
  title = "Disk health";

  variables = [
    (labelVariable "host" "Host" ''up{job="smartctl"}'')
    (labelVariable "device" "Device" ''smartctl_device{host=~"$host"}'')
  ];

  panels = [
    (row "Right now" 0)
    (firing (at 0 1 16 5) "{{alertname}} {{host}} {{device}}" [
      ''alertname="SmartctlExporterDown",host=~"$host"''
      ''alertname=~"Smartctl.*",${selected}''
    ])
    (timeline {
      title = "Exporter answering";
      gridPos = at 16 1 8 5;
      targets = [ (query "{{host}}" ''up{job="smartctl",host=~"$host"}'') ];
      states = upOrDown;
    })

    (row "Health" 6)
    (timeline {
      title = "SMART health";
      gridPos = at 0 7 12 10;
      targets = [ (query "{{device}}" "smartctl_device_smart_status{${selected}}") ];
      states = [
        (state 0 "Failing" "red")
        (state 1 "Passing" "green")
      ];
    })
    (timeline {
      title = "Read by smartctl";
      gridPos = at 12 7 12 10;
      targets = [
        (query "{{device}}" "clamp_max(smartctl_device_smartctl_exit_status{${selected}} % 8, 1)")
      ];
      states = [
        (state 0 "Read" "green")
        (state 1 "Failed" "red")
      ];
    })

    (row "Temperature and sectors" 17)
    (overTime {
      title = "Temperature";
      gridPos = at 0 18 12 9;
      defaults.unit = "celsius";
      targets = [
        (query "{{device}}" ''smartctl_device_temperature{${selected},temperature_type="current"}'')
      ];
    })
    (overTime {
      title = "Reallocated, pending and uncorrectable sectors";
      gridPos = at 12 18 12 9;
      defaults = count;
      targets = [
        (query "{{device}} {{attribute_name}}" ''smartctl_device_attribute{${selected},attribute_value_type="raw",attribute_id=~"5|197|198"}'')
      ];
    })

    (row "NVMe" 27)
    (overTime {
      title = "Rated endurance used";
      gridPos = at 0 28 6 9;
      targets = [ (query "{{device}}" "smartctl_device_percentage_used{${selected}}") ];
    })
    (overTime {
      title = "Spare blocks";
      gridPos = at 6 28 6 9;
      defaults = percent;
      targets = [
        (query "{{device}}" "smartctl_device_available_spare{${selected}}")
        (query "{{device}} alert line" "2 * smartctl_device_available_spare_threshold{${selected}}")
      ];
    })
    (overTime {
      title = "Media errors";
      gridPos = at 12 28 6 9;
      defaults = count;
      targets = [ (query "{{device}}" "smartctl_device_media_errors{${selected}}") ];
    })
    (overTime {
      title = "Critical warning flags";
      gridPos = at 18 28 6 9;
      defaults = count;
      targets = [ (query "{{device}}" "smartctl_device_critical_warning{${selected}}") ];
    })
  ];
}
