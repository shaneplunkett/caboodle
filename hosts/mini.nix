{ config, ... }:
{
  deployment = {
    systemType = "darwin";
    targetUser = "shane";
    tags = [ ];
  };

  homelab = {
    lanAddress = config.homelab.devices.mini.ip;
    monitoring.enable = false;
    tailscale.enable = false;
  };

  networking.hostName = "mini-server";

  power = {
    sleep.computer = "never";
    restartAfterPowerFailure = true;
  };
  system.defaults.loginwindow.autoLoginUser = "shane";

  system.stateVersion = 6;
}
