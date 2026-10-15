{ modulesPath, ... }:
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
    ./guest.nix
  ];

  virtualisation.podman.autoPrune = {
    enable = true;
    flags = [ "--all" ];
  };
}
