{ pkgs, ... }:
{
  homebrew.casks = [
    "chatgpt"
    "codex-app"
    "ferdium"
    "moonlight"
    "steam"
    "vesktop"
  ];

  environment.systemPackages = [ pkgs.signal-desktop ];
}
