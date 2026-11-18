{ pkgs, ... }:
{
  homebrew.casks = [
    "ferdium"
    "moonlight"
    "steam"
    "vesktop"
  ];

  environment.systemPackages = [ pkgs.signal-desktop ];
}
