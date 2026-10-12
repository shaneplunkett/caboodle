{ config, ... }:
let
  secrets = config.age.secrets;
in
{
  imports = [
    ./alerts.nix
  ];

  homelab.secrets = [ "pve-exporter" ];

  services.prometheus.exporters.pve = {
    enable = true;
    environmentFile = secrets.pve-exporter.path;
  };

  services.prometheus.scrapeConfigs = [
    {
      job_name = "pve";
      metrics_path = "/pve";
      params = {
        cluster = [ "1" ];
        node = [ "1" ];
      };
      static_configs = [ { targets = [ config.homelab.devices.pve.ip ]; } ];
      relabel_configs = [
        {
          source_labels = [ "__address__" ];
          target_label = "__param_target";
        }
        {
          source_labels = [ "__param_target" ];
          target_label = "instance";
        }
        {
          target_label = "__address__";
          replacement = "localhost:9221";
        }
      ];
    }
  ];
}
