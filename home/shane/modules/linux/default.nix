{
  lib,
  shell,
  ...
}:
{

  imports = [

    ./theme.nix
    ./files.nix
    ./cosmic.nix
    ./packages.nix
    ./linear.nix
    ./bloodborne.nix
    ./vesktop.nix
    ./waydroid.nix
    ./hyprland.nix
    ./vicinae.nix
    ./taildrop.nix
    ./screen-share.nix
  ]

  ++ lib.optionals (shell == "noctalia") [
    ./noctalia.nix
  ];

}
