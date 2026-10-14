{
  config,
  ...
}:
{

  imports = [
    ./modules/common
    ./modules/linux
  ];

  home = {
    username = "shane";
    homeDirectory = "/home/shane";
    stateVersion = "24.11";
    sessionVariables = {
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
    };
  };
  xdg = {
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
      extraConfig = {
        SCREENSHOTS = "${config.home.homeDirectory}/Screenshots";
      };
    };
  };
  programs.home-manager.enable = true;
}
