# mini-server is the homelab builder's darwin builder: the builder's Nix
# daemon sends aarch64-darwin builds here over SSH, so the Macs come out of
# the forge's CI and the homelab cache instead of building locally. The key
# can only run nix-daemon, never a shell. shane is already a trusted user,
# which ssh-ng needs to build derivations it's sent.
_:
let
  builderKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder";
in
{
  users.users.shane.openssh.authorizedKeys.keys = [
    ''restrict,command="/run/current-system/sw/bin/nix-daemon --stdio" ${builderKey}''
  ];
}
