{ config, inputs, ... }:
let
  hostKeys = import ../modules/agenix/host-keys.nix;
in
{
  imports = [
    ../modules/workstation
    ../modules/workstation/darwin
    inputs.vex-brain.darwinModules.vex-sync
  ];

  deployment = {
    systemType = "darwin";
    targetUser = "shane";
    buildOnTarget = true;
  };

  homelab = {
    secrets = [ "nix-store-key-mini" ];
    lanAddress = config.homelab.devices.mini.ip;
    routes.bubbles = 1234;
    tailscale.enable = false;
  };

  nix.settings.secret-key-files = [ config.age.secrets.nix-store-key-mini.path ];
  users.users.shane.openssh.authorizedKeys.keys = [
    "command=\"/run/current-system/sw/bin/nix-daemon --stdio\",restrict ${hostKeys.macbook} macbook"
  ];

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
