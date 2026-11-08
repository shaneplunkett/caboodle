{ config, inputs, ... }:
{
  imports = [
    ../modules/workstation
    ../modules/workstation/darwin
    ../modules/services/github-runner/darwin.nix
    inputs.vex-brain.darwinModules.vex-sync
  ];

  deployment = {
    systemType = "darwin";
    targetUser = "shane";
    buildOnTarget = true;
    tags = [ "deploy-mini" ];
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
      /usr/bin/mdutil -a -i off >/dev/null || echo "warning: could not turn Spotlight off" >&2
      /bin/launchctl enable system/com.apple.screensharing
      /bin/launchctl print system/com.apple.screensharing >/dev/null 2>&1 \
        || /bin/launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist \
        || echo "warning: could not start Screen Sharing" >&2
      /usr/sbin/dseditgroup -o edit -a shane -t user com.apple.access_screensharing \
        || echo "warning: could not let shane use Screen Sharing" >&2
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
