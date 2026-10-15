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
    routes.bubbles = 1234;
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

  system.stateVersion = 6;
}
