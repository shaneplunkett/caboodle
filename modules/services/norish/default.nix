{
  config,
  lib,
  pkgs,
  ...
}:
let
  dataDir = "/var/lib/norish";
  dumps = "/var/backup/norish";
  dump = "${dumps}/norish.dump";
  port = 3000;
  domain = "recipes.shaneplunkett.com";
  uid = 1000;
  postgres = config.services.postgresql.finalPackage;
  secrets = config.age.secrets;
in
{
  homelab = {
    secrets = [
      "norish-oidc-client-secret"
      "norish-env"
      "norish-obscura-env"
    ];

    routes.recipes = port;

    oidcClients.norish = {
      name = "Norish";
      callbackURLs = [ "https://${domain}/api/auth/oauth2/callback/oidc" ];
      launchURL = "https://${domain}/";
      groups = [ "norish_admins" ];
      secret = "norish-oidc-client-secret";
    };

    backup = {
      paths = [
        dataDir
        dumps
      ];
      exclude = [ "${dataDir}/video-temp" ];
      prepare = ''
        ${lib.getExe' pkgs.util-linux "runuser"} -u postgres -- \
          ${postgres}/bin/pg_dump -Fc -d norish -f ${dump}.tmp
        mv ${dump}.tmp ${dump}
      '';
    };

    monitoring.units = [
      "podman-norish.service"
      "podman-obscura.service"
      "postgresql.service"
      "redis-norish.service"
    ];
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    ensureDatabases = [ "norish" ];
    ensureUsers = [
      {
        name = "norish";
        ensureDBOwnership = true;
      }
    ];
  };

  services.redis.servers.norish = {
    enable = true;
    port = 6379;
  };

  users.users.norish = {
    inherit uid;
    isSystemUser = true;
    group = "norish";
  };
  users.groups.norish.gid = uid;

  virtualisation.oci-containers.containers = {
    norish = {
      image = "docker.io/norishapp/norish:v0.25.1-beta";
      dependsOn = [ "obscura" ];
      volumes = [
        "${dataDir}:/app/uploads"
        "/run/postgresql:/run/postgresql"
      ];
      environmentFiles = [
        secrets.norish-env.path
        secrets.norish-obscura-env.path
      ];
      environment = {
        AUTH_URL = "https://${domain}";
        DATABASE_URL = "postgresql://norish@localhost/norish?host=/run/postgresql";
        REDIS_URL = "redis://127.0.0.1:${toString config.services.redis.servers.norish.port}";
        OBSCURA_ENDPOINT = "ws://127.0.0.1:9222";
        UPLOADS_DIR = "/app/uploads";
        TZ = "Australia/Melbourne";
        OIDC_NAME = "Pocket ID";
        OIDC_ISSUER = "https://auth.shaneplunkett.com";
        OIDC_CLIENT_ID = "norish";
        OIDC_CLAIM_MAPPING_ENABLED = "true";
        OIDC_SCOPES = "groups";
        OIDC_ADMIN_GROUP = "norish_admins";
      };
      extraOptions = [ "--network=host" ];
    };

    obscura = {
      image = "docker.io/norishapp/obscura:0.2.5-norish.1";
      ports = [ "127.0.0.1:9222:9222" ];
      environmentFiles = [ secrets.norish-obscura-env.path ];
    };
  };

  systemd.services = {
    podman-norish = {
      environment.XDG_RUNTIME_DIR = "/run";
      after = [
        "postgresql.target"
        "redis-norish.service"
      ];
      requires = [
        "postgresql.target"
        "redis-norish.service"
      ];
    };
    podman-obscura.environment.XDG_RUNTIME_DIR = "/run";
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 ${toString uid} ${toString uid} -"
    "d ${dumps} 0700 postgres postgres -"
  ];

  networking.firewall.allowedTCPPorts = [ port ];
}
