{ inputs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    ./settings.nix
    ./homebrew.nix
    ./packages.nix
  ];
}
