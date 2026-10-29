{
  config,
  lib,
  nodes,
  ...
}:

let
  secrets = config.age.secrets;
in
{
  homelab.secrets = [
    "linear-api-key"
    "immich-glance-api-key"
  ];

  homelab.routes.dashboard = config.services.glance.settings.server.port;

  services.glance = {
    enable = true;
    openFirewall = true;
    settings = {
      server = {
        host = "0.0.0.0";
        port = 8080;
      };

      theme = import ./theme.nix;
      document.head = builtins.readFile ./auto-refresh.html;

      pages = [
        (import ./pages/home.nix { inherit nodes secrets; })
        (import ./pages/homelab.nix { inherit lib nodes; })
        (import ./pages/media.nix { inherit lib nodes; })
      ];
    };
  };
}
