{ inputs, ... }:
{

  imports = [
    ./omniwm.nix
    ./vicinae.nix
  ];

  home.file."Pictures/Wallpapers".source = inputs.wallpapers;

}
