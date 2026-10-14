{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules
    ../../modules/common
    ../../modules/nixos
    inputs.home-manager.nixosModules.default
  ];

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
