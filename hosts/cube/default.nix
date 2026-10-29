{ config, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ./smartctl.nix
    ../../modules/services/incus
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "cube";

  homelab = {
    lanAddress = config.homelab.devices.cube.ip;
    incus = {
      uplink = "enp2s0";
      inherit (config.homelab.devices.cube) mac;
    };
  };

  fileSystems =
    builtins.mapAttrs
      (_: share: {
        device = "${config.homelab.devices.pve.ip}:/mnt/user/${share}";
        fsType = "nfs";
        options = [
          "vers=4.2"
          "soft"
          "nofail"
          "_netdev"
        ];
      })
      {
        "/mnt/media" = "Media";
        "/mnt/programs" = "Programs";
      };

  systemd.services.incus = {
    wants = [ "remote-fs.target" ];
    after = [ "remote-fs.target" ];
  };

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder"
  ];

  system.stateVersion = "26.11";
}
