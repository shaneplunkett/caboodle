{ config, ... }:
let
  secrets = config.age.secrets;
in
{
  imports = [
    ./alerts.nix
  ];

  homelab.secrets = [ "unpoller-api-key" ];

  age.secrets.unpoller-api-key.owner = "unifi-poller";

  services.unpoller = {
    enable = true;
    unifi.defaults = {
      url = "https://${config.homelab.gateway}";
      verify_ssl = false;
      save_events = true;
      save_alarms = true;
      save_dpi = true;
    };
    influxdb.disable = true;
    loki.url = "http://localhost:3100";
    prometheus.http_listen = "127.0.0.1:9130";
  };

  systemd.services.unifi-poller.environment.UP_UNIFI_DEFAULT_API_KEY =
    "file://${secrets.unpoller-api-key.path}";

  services.prometheus.scrapeConfigs = [
    {
      job_name = "unpoller";
      static_configs = [ { targets = [ "localhost:9130" ]; } ];
    }
  ];
}
