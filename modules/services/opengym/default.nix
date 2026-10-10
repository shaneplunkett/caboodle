{ pkgs, ... }:
let
  dataDir = "/var/lib/opengym";
  media = "${dataDir}/media";
  port = 8080;
  apiPort = 3000;
  host = "gym.shaneplunkett.com";
in
{
  homelab = {
    routes.gym = port;
    backup.paths = [ "${dataDir}/data" ];
    monitoring.units = [
      "podman-opengym-api.service"
      "podman-opengym-web.service"
    ];
  };

  virtualisation.oci-containers.containers = {
    opengym-api = {
      image = "ghcr.io/duartesantos8/opengym-api:1.4.1";
      volumes = [ "${dataDir}/data:/data" ];
      environment = {
        PORT = toString apiPort;
        DATA_DIR = "/data";
        TRUST_PROXY = "1";
        RP_ID = host;
        RP_NAME = "openGym";
        ORIGIN = "https://${host}";
        ALLOW_GUEST = "0";
        INVITE_ONLY = "1";
      };
      extraOptions = [ "--network=host" ];
    };

    opengym-web = {
      image = "ghcr.io/duartesantos8/opengym-web:1.4.1";
      dependsOn = [ "opengym-api" ];
      volumes = [
        "${media}/img:/usr/share/nginx/html/img:ro"
        "${media}/gif:/usr/share/nginx/html/gif:ro"
      ];
      environment = {
        NGINX_PORT = toString port;
        BACKEND = "127.0.0.1";
        PORT = toString apiPort;
        RESOLVER = "127.0.0.1";
      };
      extraOptions = [ "--network=host" ];
    };
  };

  systemd.services = {
    podman-opengym-api.environment.XDG_RUNTIME_DIR = "/run";

    podman-opengym-web = {
      environment.XDG_RUNTIME_DIR = "/run";
      requires = [ "opengym-media.service" ];
      after = [ "opengym-media.service" ];
    };

    opengym-media = {
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      path = [ pkgs.git ];
      script = ''
        if [ -e ${media}/.done ]; then
          exit 0
        fi
        tmp=$(mktemp -d)
        trap 'rm -rf "$tmp"' EXIT
        git clone --depth 1 https://github.com/hasaneyldrm/exercises-dataset "$tmp/ds"
        cp "$tmp"/ds/images/*.jpg ${media}/img/
        cp "$tmp"/ds/videos/*.gif ${media}/gif/
        touch ${media}/.done
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir}/data 0750 root root -"
    "d ${media}/img 0755 root root -"
    "d ${media}/gif 0755 root root -"
  ];

  networking.firewall.allowedTCPPorts = [ port ];
}
