{
  imports = [
    ../modules/services/harmonia
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFubHsMPCTbBJk6stgFlD09uQWcqKpAoL5sKC8q5Yq2J mini-cache"
  ];
}
