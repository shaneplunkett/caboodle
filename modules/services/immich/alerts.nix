{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  photos = lib.filterAttrs (_: node: node.config.services.immich.enable or false) nodes;

  unitDown = alert: unit: what: {
    inherit alert;
    expr = ''node_systemd_unit_state{name="${unit}", state="active", host=~"${lib.concatStringsSep "|" (lib.attrNames photos)}"} == 0'';
    for = "5m";
    labels.severity = "critical";
    annotations = {
      summary = "${what} isn't running on {{ $labels.host }}";
      condition = "${unit} inactive for 5m";
      check = "ssh root@{{ $labels.host }} journalctl -u ${unit} -n 50";
    };
  };
in
{
  services.prometheus = {
    scrapeConfigs = [
      {
        job_name = "immich";
        static_configs = lib.concatLists (
          lib.mapAttrsToList (name: node: [
            {
              targets = [ "${node.config.homelab.lanAddress}:8081" ];
              labels = {
                host = name;
                worker = "api";
              };
            }
            {
              targets = [ "${node.config.homelab.lanAddress}:8082" ];
              labels = {
                host = name;
                worker = "microservices";
              };
            }
          ]) photos
        );
      }
    ];

    ruleFiles = [
      (pkgs.writeText "immich.rules.json" (
        builtins.toJSON {
          groups = [
            {
              name = "immich";
              rules = [
                (unitDown "ImmichDown" "immich-server.service" "Immich")
                (unitDown "ImmichMachineLearningDown" "immich-machine-learning.service" "Immich's machine learning")
                (unitDown "ImmichPostgresDown" "postgresql.service" "Immich's PostgreSQL")
                (unitDown "ImmichRedisDown" "redis-immich.service" "Immich's Redis")
              ];
            }
          ];
        }
      ))
    ];
  };
}
