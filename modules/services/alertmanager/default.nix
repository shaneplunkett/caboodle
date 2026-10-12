{ config, pkgs, ... }:
let
  secrets = config.age.secrets;
in
{
  homelab.secrets = [
    "discord-webhook"
    "healthchecks-ping"
  ];

  services.prometheus.alertmanager = {
    enable = true;
    openFirewall = true;
    environmentFile = secrets.discord-webhook.path;
    checkConfig = false;
    configuration = {
      templates = [ ./view.tmpl ];
      route = {
        receiver = "discord";
        group_by = [
          "alertname"
          "name"
        ];
        repeat_interval = "24h";
        routes = [
          {
            matchers = [ ''alertname="Watchdog"'' ];
            receiver = "healthchecks";
            group_wait = "0s";
            group_interval = "1m";
            repeat_interval = "1m";
          }
        ];
      };
      receivers = [
        {
          name = "discord";
          slack_configs = [
            (
              {
                api_url = "\${DISCORD_WEBHOOK_URL}/slack";
                send_resolved = true;
              }
              // import ./template.nix
            )
          ];
        }
        {
          name = "healthchecks";
          webhook_configs = [
            {
              url = "\${HEALTHCHECKS_PING_URL}";
              send_resolved = false;
            }
          ];
        }
      ];
    };
  };

  systemd.services.alertmanager.serviceConfig.EnvironmentFile = [ secrets.healthchecks-ping.path ];

  services.prometheus.ruleFiles = [
    (pkgs.writeText "watchdog.rules.json" (
      builtins.toJSON {
        groups = [
          {
            name = "watchdog";
            rules = [
              {
                alert = "Watchdog";
                expr = "vector(1)";
                annotations.summary = "Always firing, so healthchecks.io hears from Alertmanager every minute and messages Shane when it stops";
              }
            ];
          }
        ];
      }
    ))
  ];

  services.prometheus.alertmanagers = [
    { static_configs = [ { targets = [ "localhost:9093" ]; } ]; }
  ];

}
