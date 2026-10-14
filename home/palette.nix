# Catppuccin Mocha palette — the single source of truth for every module the
# catppuccin flake module doesn't theme. Delivered to home-manager modules via
# extraSpecialArgs and to system modules via specialArgs as `palette`;
# packages take it as an explicit callPackage argument.
#
# `hex` values carry no leading '#'; the formatted sets cover the common
# consumer shapes so callers never re-implement string glue.
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

  # Noctalia's 16 colour roles, shared by the shell palette and the greeter.
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
