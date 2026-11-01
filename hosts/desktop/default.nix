{
  config,
  inputs,
  ...
}:
let
  shell = "noctalia";
  hostKeys = import ../../modules/agenix/host-keys.nix;
in
{
  imports = [
    ./hardware-configuration.nix
    ./modules
    ../../modules/workstation
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
    emulation.root = "/home/shane/unraid/games";
  };

  networking.hostName = "desktop";

  homelab.secrets = [ "nix-store-key-desktop" ];
  nix = {
    settings.secret-key-files = [ config.age.secrets.nix-store-key-desktop.path ];
    sshServe = {
      enable = true;
      protocol = "ssh-ng";
      keys = [ hostKeys.deck ];
    };
  };

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
