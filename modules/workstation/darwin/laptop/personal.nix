{ pkgs, ... }:
{
  homebrew.casks = [
    "chatgpt"
    "codex-app"
    "moonlight"
    "steam"
  ];

  environment.systemPackages = [ pkgs.signal-desktop ];
}
