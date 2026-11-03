let
  grafana = "https://grafana.shaneplunkett.com/d";
  repeated = name: values: builtins.concatStringsSep "" (map (value: "&var-${name}=${value}") values);
in
{
  hostHealth = host: "${grafana}/hosts/host-health?var-host=${host}";
  logs = host: units: "${grafana}/logs/logs?var-host=${host}" + repeated "unit" units;
  diskHealth =
    host: devices: "${grafana}/disks/disk-health?var-host=${host}" + repeated "device" devices;
  storage = host: "${grafana}/storage/storage?var-host=${host}";
  backups = "${grafana}/backups/backups";
  hostBackups = host: task: "${grafana}/backups/backups?var-host=${host}&var-task=${task}";
}
