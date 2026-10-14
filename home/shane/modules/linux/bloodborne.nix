{
  lib,
  pkgs,
  ...
}:
let
  gameRoot = "/home/shane/Data/Bloodborne";

  bloodborne = pkgs.writeShellApplication {
    name = "bloodborne";
    runtimeInputs = with pkgs; [
      libnotify
      procps
    ];
    text = ''
      game_root="${gameRoot}"
      game_path="$game_root/CUSA03173"

      if pgrep -u "$UID" -f 'shadps4.*CUSA03173' >/dev/null; then
        notify-send "Bloodborne is already running" "The existing shadPS4 window is still open."
        exit 0
      fi

      if [[ ! -d "$game_path" ]]; then
        notify-send --urgency=critical "Bloodborne couldn't start" "Game data wasn't found at $game_path."
        exit 1
      fi

      cd "$game_root"
      exec ${lib.getExe pkgs.shadps4-cache-fixed} --show-fps -g "$game_path"
    '';
  };
in
{
  home.packages = [ bloodborne ];

  xdg.desktopEntries.bloodborne = {
    name = "Bloodborne";
    comment = "Hunt the nightmare through shadPS4";
    exec = lib.getExe bloodborne;
    icon = "${gameRoot}/CUSA03173/sce_sys/icon0.png";
    terminal = false;
    type = "Application";
    categories = [ "Game" ];
    settings = {
      StartupWMClass = ".shadps4-wrapped";
      PrefersNonDefaultGPU = "true";
    };
  };
}
