{ config, ... }:
let
  hostKeys = import ../modules/agenix/host-keys.nix;
  mini = config.homelab.devices.mini.ip;
in
{
  imports = [
    ../modules/workstation
    ../modules/workstation/darwin
    ../modules/workstation/darwin/laptop
  ];

  deployment = {
    systemType = "darwin";
    targetUser = "shane";
    tags = [ ];
  };

  homelab = {
    monitoring.enable = false;
    tailscale.enable = false;
  };

  networking.hostName = "Shanes-MacBook-Pro";

  nix.settings.substituters = [ "ssh-ng://shane@${mini}" ];
  programs.ssh = {
    knownHosts.mini-lan = {
      hostNames = [ mini ];
      publicKey = hostKeys.mini;
    };
    extraConfig = ''
      Match localuser root host ${mini}
        IdentityFile /etc/ssh/ssh_host_ed25519_key
        IdentitiesOnly yes
        ConnectTimeout 5
    '';
  };

  home-manager.users.shane = import ../home/shane/homemac.nix;

  system.stateVersion = 6;
}
