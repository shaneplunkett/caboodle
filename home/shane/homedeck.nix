{ lib, pkgs, ... }:
let
  steamSilent = pkgs.makeDesktopItem {
    name = "steam-silent";
    desktopName = "Steam";
    exec = "steam -silent";
  };
in
{
  imports = [ ./modules/common ];

  xdg.autostart = {
    enable = true;
    entries = [ "${steamSilent}/share/applications/steam-silent.desktop" ];
  };

  home.activation.kwinSkipRemoteControlPrompt = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kwinrc --group Xwayland --key XwaylandEisNoPrompt true
  '';

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
