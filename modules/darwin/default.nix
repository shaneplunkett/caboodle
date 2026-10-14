{ config, lib, ... }:
{
  nixpkgs.config.allowUnfree = true;

  nix = {
    optimise.automatic = true;
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 7d";
    };
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "@wheel"
        "shane"
      ];
      substituters = [
        "https://cache.shaneplunkett.com"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "cache.shaneplunkett.com-1:PCAa3NL0WuE581JmS/0zU4FQiAXUsNoKOw6leo5IIaY="
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      ];
    };
  };

  programs.fish.enable = true;

  users.users.shane = {
    home = "/Users/shane";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder"
    ];
  };
  system.primaryUser = "shane";

  security.sudo.extraConfig = ''
    shane ALL=(root) NOPASSWD: ALL
  '';

  services.prometheus.exporters.node = {
    inherit (config.homelab.monitoring) enable;
  };

  system.defaults.SoftwareUpdate.AutomaticallyInstallMacOSUpdates = lib.mkDefault false;
}
