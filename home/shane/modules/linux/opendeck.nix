{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.opendeck ];

  systemd.user.services.opendeck = {
    Unit = {
      Description = "OpenDeck Stream Deck software";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.opendeck} --hide";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
