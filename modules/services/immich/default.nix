{ config, nodes, ... }:
let
  cfg = config.services.immich;
  secrets = config.age.secrets;
in
{
  homelab = {
    secrets = [ "immich-oidc-client-secret" ];

    routes.photos = cfg.port;

    backup.paths = [ cfg.mediaLocation ];

    monitoring.units = [
      "immich-server.service"
      "immich-machine-learning.service"
      "postgresql.service"
      "redis-immich.service"
    ];
  };

  services.immich = {
    enable = true;
    host = "";
    openFirewall = true;

    environment = {
      IMMICH_TRUSTED_PROXIES = nodes.ingress.config.homelab.lanAddress;
      IMMICH_TELEMETRY_INCLUDE = "all";
      IMMICH_LOG_FORMAT = "json";
    };

    settings = {
      server.externalDomain = "https://photos.shaneplunkett.com";

      oauth = {
        enabled = true;
        issuerUrl = "https://auth.shaneplunkett.com/.well-known/openid-configuration";
        clientId = "45e64f25-acc2-4be7-a9dd-e6c7fa6ea313";
        clientSecret._secret = secrets.immich-oidc-client-secret.path;
        scope = "openid email profile";
        buttonText = "Sign in with Pocket ID";
        autoLaunch = true;
        autoRegister = false;
      };

      passwordLogin.enabled = true;

      backup.database = {
        enabled = true;
        cronExpression = "0 02 * * *";
        keepLastAmount = 14;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    8081
    8082
  ];
}
