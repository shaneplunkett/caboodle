{
  lib,
  nodes,
  group,
}:
let
  media = [
    "plex"
    "overseer"
    "prowlarr"
    "nzb"
    "deluge"
    "radarr"
    "sonarr"
    "sonarranime"
  ];

  overrides = {
    unifi.title = "UniFi";
    plex.alt-status-codes = [ 401 ];
    bubbles = {
      title = "BlueBubbles";
      icon = "di:bluebubbles.png";
    };
    coffee = {
      title = "Coffee";
      icon = "mdi:coffee";
    };
    overseer = {
      title = "Overseerr";
      icon = "di:overseerr";
    };
    nzb = {
      title = "SABnzbd";
      icon = "di:sabnzbd";
    };
    sonarranime = {
      title = "Sonarr Anime";
      icon = "di:sonarr";
    };
    dashboard.icon = "di:glance";
    status = {
      title = "Gatus";
      icon = "di:gatus";
    };
    home = {
      title = "Home Assistant";
      icon = "di:home-assistant";
    };
    zigbee = {
      title = "Zigbee2MQTT";
      icon = "di:zigbee2mqtt";
    };
    music = {
      title = "Music Assistant";
      icon = "di:music-assistant";
    };
    rss = {
      title = "FreshRSS";
      icon = "di:freshrss";
      check-url = "http://${nodes.rss.config.homelab.lanAddress}/api/";
    };
  };

  ingress = nodes.ingress.config.services;
  gated = ingress.oauth2-proxy.nginx.virtualHosts;

  nameOf = host: lib.head (lib.splitString "." host);
  groupOf = name: if lib.elem name media then "media" else "homelab";

  site =
    host:
    let
      name = nameOf host;
    in
    {
      title = lib.toSentenceCase name;
      url = "https://${host}";
      icon = "di:${name}";
    }
    // lib.optionalAttrs (gated ? ${host}) {
      check-url = ingress.nginx.virtualHosts.${host}.locations."/".proxyPass;
    }
    // overrides.${name} or { };

  proxied = lib.filterAttrs (
    _: vhost: vhost.locations."/".proxyPass or null != null
  ) ingress.nginx.virtualHosts;

  hosts = lib.filter (host: groupOf (nameOf host) == group) (lib.attrNames proxied);
in
{
  type = "monitor";
  title = "Services";
  cache = "1m";
  sites = lib.sortOn (site: lib.toLower site.title) (map site hosts);
}
