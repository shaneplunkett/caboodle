{ config, ... }:
{
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

  system.stateVersion = 6;
}
