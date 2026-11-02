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
          "x-systemd.before=incus.service"
          "x-systemd.mount-timeout=30s"
        ];
      })
      {
        "/mnt/media" = "Media";
        "/mnt/programs" = "Programs";
      };

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
  ];

  system.stateVersion = "26.11";
}
