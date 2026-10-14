{ config, pkgs, ... }:
let
  log = "${config.home.homeDirectory}/Library/Logs/bluebubbles-server.log";
in
{
  launchd.agents.bluebubbles = {
    enable = true;
    config = {
      AssociatedBundleIdentifiers = [ "com.BlueBubbles.BlueBubbles-Server" ];
      Program = "${pkgs.bluebubbles-server}/Applications/BlueBubbles.app/Contents/MacOS/BlueBubbles";
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
        Crashed = true;
      };
      StandardOutPath = log;
      StandardErrorPath = log;
    };
  };
}
