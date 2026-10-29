{
  lib,
  nodes,
  ...
}:
let
  tailnet = "tail1d49f8.ts.net";
  hostKeys = import ../agenix/host-keys.nix;

  tailnetName =
    name: node:
    if node.config.networking.hostName == "" then name else lib.toLower node.config.networking.hostName;

  hiveHosts = lib.mapAttrs (name: node: {
    hostName = tailnetName name node;
    user = node.config.homelab.sshUser;
    fish = node.config.programs.fish.enable;
  }) nodes;

  hosts = hiveHosts;

  fishHosts = lib.attrNames (lib.filterAttrs (_: host: host.fish) hosts);
in
{
  homelab.sshUser = "shane";

  programs.ssh.knownHosts = lib.mapAttrs (name: host: {
    hostNames = [
      name
      "${host.hostName}.${tailnet}"
    ];
    publicKey = hostKeys.${name};
  }) (lib.intersectAttrs hostKeys hosts);

  home-manager.users.shane.programs.ssh.settings =
    lib.mapAttrs (name: host: {
      HostName = "${host.hostName}.${tailnet}";
      HostKeyAlias = name;
      User = host.user;
    }) hosts
    // {
      "Match originalhost ${lib.concatStringsSep "," fishHosts} sessiontype shell" = {
        RequestTTY = "yes";
        RemoteCommand = "fish -l";
      };
    };
}
