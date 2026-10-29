{
  config,
  lib,
  nodes,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/aurral";
  port = 3001;
  domain = "aurral.shaneplunkett.com";
  sqlite = lib.getExe' pkgs.sqlite "sqlite3";
in
{
  homelab = {
    secrets = [
      "aurral-oidc-client-secret"
      "aurral-env"
    ];

    routes.aurral = port;

    oidcClients.aurral = {
      name = "Aurral";
      callbackURLs = [ "https://${domain}/sso/callback" ];
      launchURL = "https://${domain}/";
      groups = [ "aurral_admins" ];
      secret = "aurral-oidc-client-secret";
    };

    backup = {
      paths = [ dataDir ];
      exclude = [
        "${dataDir}/aurral.db*"
        "${dataDir}/_staging"
        "${dataDir}/image-proxy"
      ];
      prepare = ''
        if [ -e ${dataDir}/aurral.db ]; then
          ${sqlite} ${dataDir}/aurral.db ".backup ${dataDir}/backup.db"
        fi
      '';
    };

    monitoring.units = [ "podman-aurral.service" ];
  };

  virtualisation.oci-containers.containers.aurral = {
    image = "ghcr.io/lklynet/aurral:2.12.0";
    ports = [ "${toString port}:3001" ];
    volumes = [
      "${dataDir}:/config"
      "/mnt/media:/data"
    ];
    environmentFiles = [ config.age.secrets.aurral-env.path ];
    environment = {
      PUID = "99";
      PGID = "100";
      TZ = "Australia/Melbourne";
      AURRAL_PUBLIC_URL = "https://${domain}";
      TRUST_PROXY = nodes.ingress.config.homelab.lanAddress;
      OIDC_ENABLED = "true";
      OIDC_ISSUER = "https://auth.shaneplunkett.com";
      OIDC_CLIENT_ID = "aurral";
      OIDC_REDIRECT_URI = "https://${domain}/sso/callback";
      OIDC_SCOPES = "openid profile email groups";
      OIDC_GROUPS_CLAIM = "groups";
      OIDC_ADMIN_GROUPS = "aurral_admins";
      OIDC_DOMAIN = "https://auth.shaneplunkett.com";
    };
  };

  systemd.services.podman-aurral.environment.XDG_RUNTIME_DIR = "/run";

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 99 100 -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
