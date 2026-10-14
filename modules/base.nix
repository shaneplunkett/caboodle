{
  config,
  lib,
  modulesPath,
  ...
}:
let
  inherit (config.homelab.monitoring) units;
in
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  config = {
    nixpkgs.hostPlatform = "x86_64-linux"; # the LXCs' platform

    nixpkgs.config.allowUnfree = true;
    nix.optimise.automatic = true;

    programs.nh.clean = {
      enable = true;
      extraArgs = "--keep 2";
    };

    virtualisation.podman.autoPrune = {
      enable = true;
      flags = [ "--all" ];
    };

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder"
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    services.prometheus = {
      exporters.node = {
        inherit (config.homelab.monitoring) enable;
        openFirewall = true;
        enabledCollectors = lib.mkIf (units != [ ]) [ "systemd" ];
        extraFlags = [
          "--collector.textfile.directory=${config.homelab.metricsDir}"
        ]
        ++ lib.optional (units != [ ]) "--collector.systemd.unit-include=${lib.concatStringsSep "|" units}";
      };
    };

    systemd.tmpfiles.rules = [ "d ${config.homelab.metricsDir} 0755 root root -" ];

    system.stateVersion = "26.11";
  };
}
