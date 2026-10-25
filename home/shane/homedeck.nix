_: {
  imports = [ ./modules/common ];

  home = {
    username = "shane";
    homeDirectory = "/home/shane";
    stateVersion = "26.11";
  };
  xdg.configFile.kscreenlockerrc.text = ''
    [Daemon]
    Autolock=false
    LockOnResume=false
  '';

  programs.home-manager.enable = true;
}
