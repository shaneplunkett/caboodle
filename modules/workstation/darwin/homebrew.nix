{ config, inputs, ... }:
{
  imports = [ inputs.nix-homebrew.darwinModules.nix-homebrew ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    user = "shane";
    taps = {
      "homebrew/homebrew-core" = inputs.homebrew-core;
      "homebrew/homebrew-cask" = inputs.homebrew-cask;
    };
    mutableTaps = false;
  };

  homebrew = {
    enable = true;
    taps = builtins.attrNames config.nix-homebrew.taps;

    casks = [
      "ghostty"
      "tailscale-app"
    ];

    brews = [
      "mas"
    ];

    onActivation = {
      cleanup = "uninstall";
      autoUpdate = false;
      upgrade = false;
    };
  };
}
