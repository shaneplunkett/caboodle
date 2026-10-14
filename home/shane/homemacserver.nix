{ ... }:
{

  imports = [
    ./modules/common
    ./modules/mini-server/vex-code.nix
  ];

  home = {
    username = "shane";
    homeDirectory = "/Users/shane";
    stateVersion = "24.11";
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  programs.home-manager.enable = true;
}
