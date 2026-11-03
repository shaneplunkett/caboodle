{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  monitored = lib.filterAttrs (
    _: node:
    node.config.homelab.monitoring.enable
    && node.config.services.prometheus.exporters.smartctl.enable or false
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
          description = "This drive has gone from {{ $labels.host }}, or at least from the name the exporter looks for it under. That's a dead drive, a loose cable, or a swap that hasn't reached the host's `smartctl.nix`, and anything using it is failing or about to. If it's a NAS disk, hold off rebooting until you know why, because the pool won't mount with a disk missing and every share goes with it. If the check says there's no such device, `ls /dev/disk/by-id` and `journalctl -k` show whether the kernel can still see it.";
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
                    description = "Nothing is reading the drives on {{ $labels.host }} while this lasts, so a dying disk there raises no alert of its own. It says nothing about the drives themselves. See whether {{ $labels.host }} answers at all first, because a dead host is a much bigger problem than a dead exporter. If it does, the journal shows why the exporter stopped, and `systemctl restart prometheus-smartctl-exporter` is the next try.";
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
                    description = "smartctl can't get a straight answer from this drive, so its health numbers are old or missing and the other SMART alerts can't speak for it. That's either a sick drive or a bad connection, and either can become a lost disk without much more warning. Read the top of the check's output: a failed open means the system can't reach the drive at all, and a failed SMART command means it's there but not answering properly. Resets or ATA errors in `journalctl -k` on {{ $labels.host }} point the same way, and on a spinning disk, reseating the cable is the cheap thing to try before blaming the drive.";
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
                    description = "The drive's own firmware has decided it's failing, which is the last warning before it stops answering at all. Anything on it that isn't backed up is at risk right now. Find out what lives on it, make sure the backup is current, and plan the swap. `smartctl -a` shows which attribute tripped and how fast it's moving.";
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
                    description = "The drive has found bad spots on its surface and moved that data to spare sectors. One bump can be a one-off, but a count that keeps climbing is a disk on its way out. This is a NAS data disk, with no parity and no offsite copy, so what's on it only exists here. This alert clears itself once the day rolls past and the drive is no better for it, so note `Reallocated_Sector_Ct` in the check's output and compare it over the next few days. If it moves again, copy off what you can't re-download and plan the swap. `lsblk -o NAME,SERIAL,MOUNTPOINTS` on {{ $labels.host }} matches the serial to its `/mnt/diskN`.";
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
                    description = "The drive has sectors it can't read, and whatever sits on them may already be damaged. That's worse than a reallocated sector, because the data hasn't moved anywhere safe, and this is a NAS data disk with no parity and no offsite copy. Watch `Current_Pending_Sector` and `Offline_Uncorrectable` in the check's output: a small count that stays put can sit there for a long time, and a growing one means copy off what you can't re-download and plan the swap. `smartctl -t long` on the drive walks the whole surface and shows how far it goes, and takes most of a day on these disks.";
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
                    description = "Heat wears a drive out faster, and an NVMe slows itself down to cope, so this is worth sorting even though nothing has failed. Look at the temperature of the other drives in {{ $labels.host }}. If they're all up, it's the fans, the case or the room. If it's only this one, it's this drive's airflow or what's hammering it, like the nightly mover at 03:30 or a big build on the runner.";
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
                    description = "An NVMe only raises this when something is properly wrong. The number in the title adds up flags: 1 is spare space running out, 2 is temperature, 4 is reliability degraded, 8 is read-only, 16 is its backup power failed. Anything with a 4 or an 8 in it means the drive can lose data or stop taking writes at any moment, and on these hosts an NVMe holds a root disk, guests' disks or the NAS cache. `Critical Warning` in the check's output confirms the flags and `lsblk` shows what's on it. Make sure the guests' backups are current and plan the swap, unless it's only temperature, which clears when the drive cools.";
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
                    description = "The drive tried to read something and couldn't, even with its own error correction, so a block of data on it is damaged. This alert clears itself after a day and the damage stays. `lsblk` shows what's on it, and `journalctl -k` on {{ $labels.host }} names the failing sectors. If it's the NAS cache, `btrfs scrub start /mnt/cache` names the damaged files. Anything more than a one-off count in `Media and Data Integrity Errors` means plan the swap.";
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
                    description = "The drive swaps worn-out cells for spare ones, and most of its spares are gone. Once it drops under the maker's threshold it raises a critical warning and can stop taking writes, so there's time but not forever. Compare `Available Spare` with `Percentage Used` in the check's output: low spare on a drive with plenty of life left means it's failing early rather than wearing out. Order a replacement and watch how fast the number falls, since that sets how long you've got.";
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
                    description = "The drive has written nearly all the data its maker rated it for. That isn't a failure, and plenty of drives run well past 100%, but from here nothing promises it keeps going. This number moves slowly, so it's a job for this month. `lsblk` shows what's on it, and `Data Units Written` in the check's output shows how hard it has been worked, which says whether the replacement should be a tougher drive. Plan the swap while it's still a choice.";
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
