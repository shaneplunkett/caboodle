{
  config,
  lib,
  nodes,
  ...
}:
let
  secrets = config.age.secrets;
  inherit (config.homelab) devices;
  domain = "shaneplunkett.com";
  oauthName = "oauth";
  oauthHost = "${oauthName}.${domain}";

  gated = {
    overseer = [ "/api/" ];
    sonarr = [ "/api/" ];
    sonarranime = [ "/api/" ];
    radarr = [ "/api/" ];
    prowlarr = [
      "/api/"
      "~ ^/[0-9]+/(api|download)"
    ];
    nzb = [
      "/api"
      "/sabnzbd/api"
    ];
    deluge = [ ];
    dispatcharr = [ ];
    rss = [ "/api/" ];
    zigbee = [ ];
    music = [ ];
    papergpt = [ ];
  };

  externalRoutes = {
    proxmox = "https://${devices.cube.ip}:8006";
    unifi = "https://${config.homelab.gateway}:443";
    coffee = "http://${devices.gaggiuino.ip}:80";
  };

  serverConfig = {
    coffee = ''
      add_header Content-Security-Policy "upgrade-insecure-requests" always;
    '';
    photos = ''
      proxy_request_buffering off;
      client_body_buffer_size 1024k;
      proxy_read_timeout 600s;
      proxy_send_timeout 600s;
      send_timeout 600s;
    '';
  };

  hiveRoutes = lib.concatMapAttrs (
    _: node:
    lib.mapAttrs (
      _: port: "http://${node.config.homelab.lanAddress}:${toString port}"
    ) node.config.homelab.routes
  ) nodes;

  routeNames = [
    oauthName
  ]
  ++ lib.attrNames externalRoutes
  ++ lib.concatMap (node: lib.attrNames node.config.homelab.routes) (lib.attrValues nodes);

  routes = externalRoutes // hiveRoutes;
in
{
  imports = [ ./oauth2-proxy.nix ];

  homelab.secrets = [ "cloudflare-dns" ];

  assertions = [
    {
      assertion = lib.allUnique routeNames;
      message = "Two routes claim the same subdomain: ${toString routeNames}";
    }
  ];

  security.acme = {
    acceptTerms = true;
    certs.${domain} = {
      domain = "*.${domain}";
      extraDomainNames = [ "*.shaneplunkett.dev" ];
      dnsProvider = "cloudflare";
      environmentFile = secrets.cloudflare-dns.path;
      dnsResolver = "1.1.1.1:53";
      group = config.services.nginx.group;
    };
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    clientMaxBodySize = "0";

    virtualHosts =
      lib.mapAttrs' (
        name: upstream:
        lib.nameValuePair "${name}.${domain}" {
          useACMEHost = domain;
          forceSSL = true;
          extraConfig = serverConfig.${name} or "";
          locations = lib.genAttrs ([ "/" ] ++ gated.${name} or [ ]) (path: {
            proxyPass = upstream;
            proxyWebsockets = true;
            extraConfig = lib.mkIf (path != "/") "auth_request off;";
          });
        }
      ) routes
      // {
        ${oauthHost} = {
          useACMEHost = domain;
          forceSSL = true;
          locations."/".return = "404";
        };
        "_" = {
          default = true;
          useACMEHost = domain;
          forceSSL = true;
          locations."/".return = "404";
        };
      };
  };

  services.oauth2-proxy.nginx = {
    domain = oauthHost;
    virtualHosts = lib.mapAttrs' (
      name: _: lib.nameValuePair "${name}.${domain}" { allowed_groups = [ "media_admins" ]; }
    ) gated;
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
