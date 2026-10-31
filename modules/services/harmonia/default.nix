{ config, ... }:
let
  port = 5000;
in
{
  homelab.secrets = [ "nix-cache-signing-key" ];

  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.age.secrets.nix-cache-signing-key.path ];
    settings.bind = "[::]:${toString port}";
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
