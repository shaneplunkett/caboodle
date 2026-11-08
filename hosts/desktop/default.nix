{
  config,
  inputs,
  ...
}:
let
  shell = "noctalia";
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules
    ../../modules/workstation
    ../../modules/services/harmonia/pusher.nix
    ../../modules/workstation/nixos
  ];

  deployment = {
    tags = [ ];
    allowLocalDeployment = true;
  };

  homelab = {
    lanAddress = config.homelab.devices.nixDesktop.ip;
    monitoring.enable = false;
    tailscale.enable = false;
    emulation = {
      root = "/home/shane/unraid/games";
      edenInstalls = "/home/shane/Data/eden/Contents";
    };
  };

  networking.hostName = "desktop";

  _module.args = { inherit shell; };

  home-manager = {
    extraSpecialArgs = { inherit shell; };
    sharedModules = [ inputs.noctalia.homeModules.default ];
    users.shane = import ../../home/shane/home.nix;
  };

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
      bootCounting.enable = true;
    };
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "24.11";
}
