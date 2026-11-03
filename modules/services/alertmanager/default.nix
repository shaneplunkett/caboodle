{ config, pkgs, ... }:
let
  bridge = config.homelab.linearBridge;
in
{
  services.prometheus.alertmanager = {
    enable = true;
    openFirewall = true;
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
            matchers = [ ''alertname="${bridge.watchdogAlert}"'' ];
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
                alert = bridge.watchdogAlert;
                expr = "vector(1)";
                annotations.summary = "Always firing, so healthchecks.io hears through the bridge every two minutes and messages Shane when it stops";
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
