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

  home-manager.users.shane = import ../home/shane/homemac.nix;

  system.stateVersion = 6;
}
