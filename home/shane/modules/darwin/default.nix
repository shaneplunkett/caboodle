{ inputs, pkgs, ... }:
{

  imports = [
    ../vesktop.nix
    ./omniwm.nix
    ./vicinae.nix
  ];

  home = {
    file."Pictures/Wallpapers".source = inputs.wallpapers;
    packages = [ pkgs.slack-themed ];
  };

  programs.vesktop.package = null;

}
