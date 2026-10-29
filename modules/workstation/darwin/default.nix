{ inputs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ./settings.nix
    ./homebrew.nix
    ./packages.nix
  ];

  _module.args.palette = import ../../../home/palette.nix;
}
