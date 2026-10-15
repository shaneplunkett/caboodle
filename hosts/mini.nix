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
    restartAfterFreeze = true;
  };

  system = {
    defaults.loginwindow.autoLoginUser = "shane";
    activationScripts.postActivation.text = ''
      /usr/bin/mdutil -a -i off >/dev/null
    '';
    stateVersion = 6;
  };

  home-manager.users.shane = {
    imports = [ ../home/shane/homemacserver.nix ];
    programs.vex-cli.sync.enable = false;
  };

  services.vex-sync = {
    enable = true;
    user = "shane";
  };
}
