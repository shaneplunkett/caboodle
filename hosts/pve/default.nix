{ config, inputs, ... }:
{
  imports = [
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/services/incus
    ../../modules/services/nas
  ];

  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  networking.hostName = "pve";

  homelab = {
    monitoring.enable = false;
    tailscale.subnetRouter = true;
    incus = {
      uplink = "eno1";
      inherit (config.homelab.devices.pve) mac;
      storage = "/dev/disk/by-partlabel/disk-main-incus";
    };
  };

  services.openssh.enable = true;

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder"
  ];

  system.stateVersion = "26.11";
}
