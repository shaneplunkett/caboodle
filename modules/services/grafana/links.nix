let
  grafana = "https://grafana.shaneplunkett.com/d";
in
{
  hostHealth = host: "${grafana}/hosts/host-health?var-host=${host}";
  logs =
    host: units:
    "${grafana}/logs/logs?var-host=${host}"
    + builtins.concatStringsSep "" (map (unit: "&var-unit=${unit}") units);
}
