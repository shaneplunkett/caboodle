{ pkgs, ... }:
{
  homebrew.casks = [
    "moonlight"
    "steam"
  ];

  environment.systemPackages = [ pkgs.signal-desktop ];
}
