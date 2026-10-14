{ inputs, lib, ... }:
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
    inputs.catppuccin.nixosModules.catppuccin
    ./audio.nix
    ./docker.nix
    ./fonts.nix
    ./homedrives.nix
    ./locale.nix
    ./user.nix
  ];

  catppuccin.autoEnable = lib.mkDefault false;

  _module.args = {
    palette = import ../../../home/palette.nix;
    typography = import ../../../home/typography.nix;
  };
}
