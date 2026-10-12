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
    "proxmox-token"
    "linear-api-key"
    "unraid-api-key"
    "immich-glance-api-key"
  ];

  homelab.routes.dashboard = config.services.glance.settings.server.port;

  services.glance = {
    enable = true;
    openFirewall = true;
    environmentFile = secrets.proxmox-token.path;
    settings = {
      server = {
        host = "0.0.0.0";
        port = 8080;
      };

      theme = import ./theme.nix;
      document.head = builtins.readFile ./auto-refresh.html;

      pages = [
        (import ./pages/home.nix { inherit nodes secrets; })
        (import ./pages/homelab.nix { inherit lib nodes secrets; })
        (import ./pages/media.nix { inherit lib nodes; })
      ];
    };
  };
}
