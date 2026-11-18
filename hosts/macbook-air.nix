{ inputs, ... }:
{
  imports = [
    ../modules/workstation
    ../modules/workstation/darwin
    ../modules/workstation/darwin/laptop
  ];

  disabledModules = [ ../modules/workstation/darwin/laptop/personal.nix ];

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

  home-manager.users.shane =
    { lib, ... }:
    {
      imports = [
        ../home/shane/homemac.nix
        inputs.nix-config-private.homeManagerModules.work
      ];

      disabledModules = [
        ../home/shane/modules/common/ai
        ../home/shane/modules/common/personal.nix
        ../home/shane/modules/vesktop.nix
      ];

      programs.vex-cli.enable = lib.mkForce false;
    };

  system.stateVersion = 6;
}
