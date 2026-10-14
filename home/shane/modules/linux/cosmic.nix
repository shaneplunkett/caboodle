# Catppuccin for COSMIC apps (COSMIC Files and the file picker).
# COSMIC apps read a fully built theme that cosmic-settings-daemon normally
# generates from builder settings. Outside COSMIC nothing does, so write the
# builder settings from the palette and the shared accent, and build the
# theme with cosmic-ctl.
{
  config,
  lib,
  palette,
  pkgs,
  ...
}:
let
  inherit (config.catppuccin) accent;
  colour = name: "\"#${palette.hex.${name}}ff\"";

  # The same mapping as Catppuccin's cosmic-desktop Mocha theme. COSMIC
  # derives every other colour from these, so the theme follows palette.nix.
  cosmicPalette = lib.mapAttrs (_: colour) {
    bright_red = "red";
    bright_green = "green";
    bright_orange = "peach";
    gray_1 = "mantle";
    gray_2 = "base";
    neutral_0 = "crust";
    neutral_1 = "mantle";
    neutral_2 = "base";
    neutral_3 = "surface0";
    neutral_4 = "surface1";
    neutral_5 = "surface2";
    neutral_6 = "overlay0";
    neutral_7 = "overlay1";
    neutral_8 = "overlay2";
    neutral_9 = "subtext0";
    neutral_10 = "subtext1";
    accent_blue = "blue";
    accent_indigo = "mauve";
    accent_purple = "lavender";
    accent_pink = "pink";
    accent_red = "red";
    accent_orange = "peach";
    accent_yellow = "yellow";
    accent_green = "green";
    accent_warm_grey = "overlay2";
    ext_warm_grey = "overlay2";
    ext_orange = "peach";
    ext_yellow = "yellow";
    ext_blue = "blue";
    ext_purple = "lavender";
    ext_pink = "pink";
    ext_indigo = "mauve";
  };

  # One file per builder field, as COSMIC's config keeps them. Spacing,
  # corner radii, gaps and blur stay at COSMIC's defaults.
  builder =
    lib.mapAttrs (_: name: "Some(${colour name})") {
      bg_color = "base";
      primary_container_bg = "surface0";
      secondary_container_bg = "surface1";
      text_tint = "text";
      neutral_tint = "overlay1";
      inherit accent;
      window_hint = accent;
      success = "green";
      warning = "yellow";
      destructive = "red";
    }
    // {
      palette = ''
        Dark((
            name: "Catppuccin-Mocha-${accent}",
        ${
          lib.concatStrings (lib.mapAttrsToList (field: value: "    ${field}: ${value},\n") cosmicPalette)
        }))
      '';
    };

  builderDir = pkgs.linkFarm "cosmic-theme-builder" (
    lib.mapAttrsToList (name: value: {
      inherit name;
      path = pkgs.writeText name value;
    }) builder
  );

  theme =
    pkgs.runCommand "cosmic-catppuccin-mocha-${accent}"
      { nativeBuildInputs = [ pkgs.cosmic-ext-ctl-v2 ]; }
      ''
        export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR/config
        mkdir -p $XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Dark.Builder
        cp -rL ${builderDir} $XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Dark.Builder/v2
        cosmic-ctl build-theme

        # cosmic-ctl falls back to COSMIC's defaults for any builder field it
        # can't parse, so fail here rather than ship a half-default theme.
        theme=$XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Dark/v2
        grep -q Catppuccin $theme/name
        grep -qi 'base: "#${palette.hex.${accent}}ff"' $theme/accent
        grep -qi '^    base: "#${palette.hex.base}ff"' $theme/background

        cp -r $XDG_CONFIG_HOME/cosmic/com.system76.CosmicTheme.Dark/v2 $out
      '';

  # COSMIC's font setting: a family plus enum weight, stretch and style.
  font = family: "(family: \"${family}\", weight: Normal, stretch: Normal, style: Normal)";
in
{
  xdg.configFile = {
    "cosmic/com.system76.CosmicTheme.Dark/v2".source = theme;
    "cosmic/com.system76.CosmicTheme.Mode/v1/is_dark".text = "true";

    # Same icons and fonts as GTK and Qt (theme.nix).
    "cosmic/com.system76.CosmicTk/v1/icon_theme".text = "\"${config.gtk.iconTheme.name}\"";
    "cosmic/com.system76.CosmicTk/v1/interface_font".text = font config.gtk.font.name;
    "cosmic/com.system76.CosmicTk/v1/monospace_font".text = font (
      lib.head config.fonts.fontconfig.defaultFonts.monospace
    );
  };
}
