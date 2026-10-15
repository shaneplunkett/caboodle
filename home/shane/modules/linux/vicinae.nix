{ config, ... }:
let
  # Catppuccin's module asks for a "Catppuccin Mocha Mauve" icon theme under a
  # camelCase key vicinae doesn't read. Use the desktop's icon theme instead.
  iconTheme.icon_theme = config.gtk.iconTheme.name;
in
{
  programs.vicinae = {
    enable = true;
    systemd.enable = true;

    settings = {
      font.normal.family = config.gtk.font.name;

      theme = {
        dark = iconTheme;
        light = iconTheme;
      };

      # Hyprland owns the toggle on SUPER+space; an empty string drops
      # vicinae's own global shortcut, which defaults to alt+space.
      global_shortcuts.toggle = "";
    };
  };
}
