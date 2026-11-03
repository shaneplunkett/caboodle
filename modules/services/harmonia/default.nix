{ config, lib, ... }:
let
  inherit (import ./cache.nix) port;
in
{
  homelab.secrets = [ "nix-store-key-cache" ];

  services.harmonia.cache = {
    enable = true;
    signKeyPaths = [ config.age.secrets.nix-store-key-cache.path ];
    settings = {
      bind = "[::]:${toString port}";
      priority = 30;
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];

  systemd.tmpfiles.rules = [ "d /nix/var/nix/profiles/per-host 0755 root root -" ];

  programs.nh.clean.enable = lib.mkForce false;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
}
