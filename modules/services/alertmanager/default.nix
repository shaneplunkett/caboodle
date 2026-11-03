{ config, pkgs, ... }:
let
  secrets = config.age.secrets;
  bridge = config.homelab.linearBridge;
in
{
  homelab.secrets = [ "healthchecks-ping" ];

  services.prometheus.alertmanager = {
    enable = true;
    openFirewall = true;
    environmentFile = secrets.healthchecks-ping.path;
    checkConfig = false;
    configuration = {
      route = {
        receiver = "linear";
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
          name = "linear";
          webhook_configs = [
            {
              url = "http://127.0.0.1:${toString bridge.port}/alerts";
              send_resolved = true;
            }
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
