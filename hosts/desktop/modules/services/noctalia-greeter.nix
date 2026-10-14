# greetd login screen matching the Noctalia shell. The greeter ships its own
# compositor, so no cage wrapper; [output] pins it to DP-2 instead.
{
  inputs,
  palette,
  typography,
  pkgs,
  ...
}:
{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  services.displayManager.noctalia-greeter = {
    enable = true;

    settings = {
      session.default = "Hyprland";
      user.default = "shane";

      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
        font_family = typography.ui;
        palette = palette.noctaliaRoles;
        wallpaper = {
          path = "${../../assets/greeter-bg.jpg}";
          fill_mode = "crop";
        };
      };

      output.name = "DP-2";

      cursor = {
        theme = "catppuccin-mocha-mauve-cursors";
        path = pkgs.catppuccin-cursors.mochaMauve;
      };
    };
  };
}
