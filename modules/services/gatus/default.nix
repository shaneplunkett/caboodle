{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  secrets = config.age.secrets;
  monitoring = nodes.monitoring.config.homelab.lanAddress;
  state = "/var/lib/private/gatus";
in
{
  homelab = {
    secrets = [
      "discord-webhook"
    ];

    routes.status = config.services.gatus.settings.web.port;

    backup = {
      paths = [ state ];
      exclude = [ "${state}/data.db*" ];
      prepare = ''
        ${lib.getExe' pkgs.sqlite "sqlite3"} ${state}/data.db ".backup ${state}/backup.db"
      '';
    };
  };

  services.gatus = {
    enable = true;
    openFirewall = true;
    environmentFile = secrets.discord-webhook.path;

    settings = {
      web.port = 8082;

      storage = {
        type = "sqlite";
        path = "/var/lib/gatus/data.db";
      };

      metrics = true;
      alerting.discord.webhook-url = "\${DISCORD_WEBHOOK_URL}";

      endpoints = [
        {
          name = "Prometheus";
          group = "Infrastructure";
          url = "http://${monitoring}:9090/-/healthy";
          interval = "1m";
          conditions = [
            "[STATUS] == 200"
          ];
          alerts = [
            {
              type = "discord";
              send-on-resolved = true;
            }
          ];
        }
        {
          name = "Alertmanager";
          group = "Infrastructure";
          url = "http://${monitoring}:9093/-/healthy";
          interval = "1m";
          conditions = [
            "[STATUS] == 200"
          ];
          alerts = [
            {
              type = "discord";
              send-on-resolved = true;
            }
          ];
        }
      ];
    };
  };
}
