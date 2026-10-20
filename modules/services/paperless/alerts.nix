{
  lib,
  nodes,
  pkgs,
  ...
}:
let
  links = import ../grafana/links.nix;
  paper = lib.filterAttrs (_: node: node.config.services.paperless.enable or false) nodes;

  unitDown = alert: unit: what: {
    inherit alert;
    expr = ''node_systemd_unit_state{name="${unit}", state="active", host=~"${lib.concatStringsSep "|" (lib.attrNames paper)}"} == 0'';
    for = "15m";
    labels.severity = "critical";
    annotations = {
      summary = "${what} isn't running on {{ $labels.host }}";
      condition = "${unit} inactive for 15m";
      check = "ssh root@{{ $labels.host }} journalctl -u ${unit} -n 50";
      dashboard = links.logs "{{ $labels.host }}" [ unit ];
    };
  };
in
{
  services.prometheus.ruleFiles = [
    (pkgs.writeText "paperless.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "paperless";
            rules = [
              (unitDown "PaperlessDown" "paperless-web.service" "Paperless")
              (unitDown "PaperlessConsumerDown" "paperless-consumer.service" "Paperless's consumer")
              (unitDown "PaperlessSchedulerDown" "paperless-scheduler.service" "Paperless's scheduler")
              (unitDown "PaperlessTaskQueueDown" "paperless-task-queue.service" "Paperless's task queue")
              (unitDown "PaperlessPostgresDown" "postgresql.service" "Paperless's PostgreSQL")
              (unitDown "PaperlessRedisDown" "redis-paperless.service" "Paperless's Redis")
              (unitDown "PaperlessTikaDown" "tika.service" "Paperless's Tika")
              (unitDown "PaperlessGotenbergDown" "gotenberg.service" "Paperless's Gotenberg")
            ];
          }
        ];
      }
    ))
  ];
}
