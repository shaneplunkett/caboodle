{
  nixpkgs.hostPlatform = "x86_64-linux";

  virtualisation.podman.autoPrune = {
    enable = true;
    flags = [ "--all" ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder"
  ];

  system.stateVersion = "26.11";
}
