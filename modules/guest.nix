{ config, lib, ... }:
{
  nixpkgs.hostPlatform = "x86_64-linux";

  virtualisation.podman.autoPrune = {
    enable = true;
    flags = [ "--all" ];
  };

  users.users.root.openssh.authorizedKeys.keys =
  [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
  ]
  ++ lib.optional config.homelab.deployedByRunner "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwMm4iT56bQb/ujy15aoiHBZueU5FexFQNusMCq7BFD runner-deploy";

  system.stateVersion = "26.11";
}
