let
  hex = {
    rosewater = "f5e0dc";
    flamingo = "f2cdcd";
    pink = "f5c2e7";
    mauve = "cba6f7";
    red = "f38ba8";
    maroon = "eba0ac";
    peach = "fab387";
    yellow = "f9e2af";
    green = "a6e3a1";
    teal = "94e2d5";
    sky = "89dceb";
    sapphire = "74c7ec";
    blue = "89b4fa";
    lavender = "b4befe";
    text = "cdd6f4";
    subtext1 = "bac2de";
    subtext0 = "a6adc8";
    overlay2 = "9399b2";
    overlay1 = "7f849c";
    overlay0 = "6c7086";
    surface2 = "585b70";
    surface1 = "45475a";
    surface0 = "313244";
    base = "1e1e2e";
    mantle = "181825";
    crust = "11111b";
  };
in
{
  inherit hex;
  withHash = builtins.mapAttrs (_: v: "#${v}") hex;
  hyprRgba = builtins.mapAttrs (_: v: "rgba(${v}ff)") hex;

  # Noctalia's built-in Catppuccin uses mauve as primary; this keeps lavender.
  noctaliaRoles = builtins.mapAttrs (_: name: "#${hex.${name}}") {
    primary = "lavender";
    on_primary = "crust";
    secondary = "teal";
    on_secondary = "crust";
    tertiary = "peach";
    on_tertiary = "crust";
    error = "red";
    on_error = "crust";
    surface = "base";
    on_surface = "text";
    surface_variant = "surface0";
    on_surface_variant = "subtext1";
    outline = "overlay0";
    shadow = "crust";
    hover = "surface1";
    on_hover = "text";
  };
}
