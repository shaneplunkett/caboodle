{ config, ... }:
let
  cfg = config.services.zigbee2mqtt;
  port = 8080;
in
{
  homelab = {
    routes.zigbee = port;
    secrets = [ "zigbee2mqtt-secret" ];
    backup.paths = [ cfg.dataDir ];
    monitoring.units = [ "zigbee2mqtt.service" ];
  };

  age.secrets.zigbee2mqtt-secret.owner = "zigbee2mqtt";

  services.zigbee2mqtt = {
    enable = true;
    settings = {
      version = 5;
      homeassistant.enabled = true;
      availability.enabled = true;
      mqtt.server = "mqtt://127.0.0.1:1883";
      serial = {
        port = "tcp://${config.homelab.devices.slzb.ip}:6638";
        adapter = "zstack";
      };
      advanced = {
        channel = 15;
        pan_id = 19140;
        ext_pan_id = [
          89
          35
          36
          25
          172
          94
          78
          180
        ];
        network_key = "!secret network_key";
        log_output = [ "console" ];
        log_namespaced_levels."z2m:mqtt" = "warning";
      };
      frontend = {
        enabled = true;
        inherit port;
      };
    };
  };

  systemd.services.zigbee2mqtt = {
    after = [ "mosquitto.service" ];
    wants = [ "mosquitto.service" ];
  };

  systemd.tmpfiles.rules = [
    "d ${cfg.dataDir} 0700 zigbee2mqtt zigbee2mqtt -"
    "L+ ${cfg.dataDir}/secret.yaml - - - - ${config.age.secrets.zigbee2mqtt-secret.path}"
  ];

  networking.firewall.allowedTCPPorts = [ port ];
}
