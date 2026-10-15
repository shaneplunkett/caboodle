{ modulesPath, name, ... }:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/virtualisation/disk-image.nix")
    ./guest.nix
  ];

  networking.hostName = name;

  services.qemuGuest.enable = true;
  services.openssh.enable = true;
}
