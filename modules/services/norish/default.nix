{ config, pkgs, ... }:
let
  dataDir = "/var/lib/norish";
  port = 3000;
  domain = "recipes.shaneplunkett.com";
  uid = 1000;
in
{
  homelab.monitoring.units = [
    "podman-norish.service"
    "podman-obscura.service"
    "postgresql.service"
    "redis-norish.service"
  ];

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
      environment = {
        AUTH_URL = "https://${domain}";
        DATABASE_URL = "postgresql://norish@localhost/norish?host=/run/postgresql";
        REDIS_URL = "redis://127.0.0.1:${toString config.services.redis.servers.norish.port}";
        OBSCURA_ENDPOINT = "ws://127.0.0.1:9222";
        UPLOADS_DIR = "/app/uploads";
        TZ = "Australia/Melbourne";
      };
      extraOptions = [ "--network=host" ];
    };

    obscura = {
      image = "docker.io/norishapp/obscura:0.2.5-norish.1";
      ports = [ "127.0.0.1:9222:9222" ];
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

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 ${toString uid} ${toString uid} -" ];

  networking.firewall.allowedTCPPorts = [ port ];
}
