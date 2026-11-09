{ inputs, ... }:
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

  networking = {
    computerName = "Shane's MacBook Air";
    hostName = "Shanes-MacBook-Air";
  };

  home-manager.users.shane.imports = [
    ../home/shane/homemac.nix
    inputs.nix-config-private.homeManagerModules.work
  ];

  system.stateVersion = 6;
}
