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
    };
  };

  programs.fish.enable = true;

  users.users.shane = {
    home = "/Users/shane";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
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
