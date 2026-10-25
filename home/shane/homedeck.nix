{ lib, pkgs, ... }:
let
  steamSilent = pkgs.makeDesktopItem {
    name = "steam-silent";
    desktopName = "Steam";
    exec = "steam -silent";
  };

  steamPad = "engine:sdl,port:0,guid:03000000de280000ff11000001000000";
  button = number: ''"${steamPad},button:${toString number}"'';
  dpad = direction: ''"${steamPad},direction:${direction},hat:0"'';
  trigger = axis: ''"${steamPad},invert:+,axis:${toString axis},threshold:0.500000"'';
  stick =
    x: y:
    ''"${steamPad},axis_x:${toString x},offset_x:-0.000000,axis_y:${toString y},offset_y:0.000000,invert_x:+,invert_y:+,deadzone:0.150000"'';
  edenControls = pkgs.writeText "eden-controls.json" (
    builtins.toJSON {
      player_0_connected = "true";
      player_0_type = "0";
      player_0_button_a = button 1;
      player_0_button_b = button 0;
      player_0_button_x = button 3;
      player_0_button_y = button 2;
      player_0_button_l = button 4;
      player_0_button_r = button 5;
      player_0_button_sl = button 4;
      player_0_button_sr = button 5;
      player_0_button_minus = button 6;
      player_0_button_plus = button 7;
      player_0_button_home = button 8;
      player_0_button_lstick = button 9;
      player_0_button_rstick = button 10;
      player_0_button_dup = dpad "up";
      player_0_button_ddown = dpad "down";
      player_0_button_dleft = dpad "left";
      player_0_button_dright = dpad "right";
      player_0_button_zl = trigger 2;
      player_0_button_zr = trigger 5;
      player_0_lstick = stick 0 1;
      player_0_rstick = stick 3 4;
    }
  );

  azaharPad = "engine:sdl,guid:030079f6de280000ff11000001000000,port:0";
  azaharButton = number: ''"button:${toString number},${azaharPad}"'';
  azaharDpad = direction: ''"direction:${direction},hat:0,${azaharPad}"'';
  azaharTrigger = axis: ''"axis:${toString axis},direction:+,threshold:0.5,${azaharPad}"'';
  azaharStick = x: y: ''"axis_x:${toString x},axis_y:${toString y},deadzone:0.100000,${azaharPad}"'';
  azaharControls = pkgs.writeText "azahar-controls.json" (
    builtins.toJSON {
      profile = "0";
      "profiles\\size" = "1";
      "profiles\\1\\name" = "default";
      "profiles\\1\\button_a" = azaharButton 1;
      "profiles\\1\\button_b" = azaharButton 0;
      "profiles\\1\\button_x" = azaharButton 3;
      "profiles\\1\\button_y" = azaharButton 2;
      "profiles\\1\\button_zl" = azaharButton 4;
      "profiles\\1\\button_zr" = azaharButton 5;
      "profiles\\1\\button_select" = azaharButton 6;
      "profiles\\1\\button_start" = azaharButton 7;
      "profiles\\1\\button_up" = azaharDpad "up";
      "profiles\\1\\button_down" = azaharDpad "down";
      "profiles\\1\\button_left" = azaharDpad "left";
      "profiles\\1\\button_right" = azaharDpad "right";
      "profiles\\1\\button_l" = azaharTrigger 2;
      "profiles\\1\\button_r" = azaharTrigger 5;
      "profiles\\1\\circle_pad" = azaharStick 0 1;
      "profiles\\1\\c_stick" = azaharStick 3 4;
    }
  );
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

  home.activation.emulatorSteamPad = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 -I ${../../modules/workstation/nixos/emulator-controls.py} "$HOME/.config/eden/qt-config.ini" Controls ${edenControls} --qt
    run ${pkgs.python3}/bin/python3 -I ${../../modules/workstation/nixos/emulator-controls.py} "$HOME/.config/azahar-emu/qt-config.ini" Controls ${azaharControls} --qt
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
