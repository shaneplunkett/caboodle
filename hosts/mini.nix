{ config, inputs, ... }:
{
  imports = [
    ../modules/workstation
    ../modules/workstation/darwin
    inputs.vex-brain.darwinModules.vex-sync
  ];

  deployment = {
    systemType = "darwin";
    targetUser = "shane";
  };

  homelab = {
    lanAddress = config.homelab.devices.mini.ip;
    tailscale.enable = false;
  };

  networking = {
    hostName = "mini-server";
    applicationFirewall.enable = false;
  };

  power = {
    sleep.computer = "never";
    restartAfterPowerFailure = true;
  };
  system.defaults.loginwindow.autoLoginUser = "shane";

  home-manager.users.shane = {
    imports = [ ../home/shane/homemacserver.nix ];
    programs.vex-cli.sync.enable = false;
  };

  services.vex-sync = {
    enable = true;
    user = "shane";
  };

  homebrew.casks = [ "bluebubbles" ];

  system.stateVersion = 6;
}
