{ pkgs, typography, ... }:
let
  uiFont = typography.ui;
  codeFont = typography.code;
  fontSize = 12;
  cursorSize = 24;

  # One icon theme for GTK, Qt and noctalia's app icons alike.
  iconTheme = {
    name = "Reversal-purple-dark";
    package = pkgs.reversal-icon-theme.override { colorVariants = [ "purple" ]; };
  };

  # Qt's font string: family,points,-1,5,weight,then style flags.
  qtFont = family: "${family},${toString fontSize},-1,5,400,0,0,0,0,0,0,0,0,0,0,1";
in
{
  # Most apps (Chrome, Electron, Flutter, Hyprland) take their fonts from these
  # fontconfig defaults rather than GTK.
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      sansSerif = [ uiFont ];
      serif = [ uiFont ];
      monospace = [ codeFont ];
    };
  };

  # Apps read light/dark via the xdg-desktop-portal Settings interface, which is
  # backed by this dconf key. Nothing else asserts it (noctalia only syncs it when
  # user theming/templates are enabled), so own it declaratively. The font keys
  # are what GTK4/libadwaita apps read.
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    font-name = "${uiFont} ${toString fontSize}";
    document-font-name = "${uiFont} ${toString fontSize}";
    monospace-font-name = "${codeFont} ${toString fontSize}";
    # Chromium builds its AT-SPI tree only when this is set at startup; T3
    # SnapShots' "Include app text" reads that tree.
    toolkit-accessibility = true;
  };

  # The cursor theme itself comes from catppuccin.cursors below.
  home.pointerCursor = {
    enable = true;
    size = cursorSize;
    gtk.enable = true;
    x11.enable = true;
  };

  gtk = {
    enable = true;

    font = {
      package = pkgs.roundhog;
      name = uiFont;
      size = fontSize;
    };

    inherit iconTheme;

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.theme = null;
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk3.bookmarks = [
      "file:///home/shane/Documents Documents"
      "file:///home/shane/Projects Projects"
      "file:///home/shane/Downloads Downloads"
      "file:///home/shane/Music Music"
      "file:///home/shane/Pictures Pictures"
      "file:///home/shane/Templates Templates"
      "file:///home/shane/Videos Videos"
      "file:///home/shane/Screenshots Screenshots"
      "file:///home/shane/unraid Unraid"
    ];
  };

  # qt6ct carries the icons and fonts; Kvantum draws the widgets in Catppuccin.
  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    qt6ctSettings = {
      Appearance = {
        icon_theme = iconTheme.name;
        style = "kvantum";
        custom_palette = false;
        standard_dialogs = "default";
      };
      Fonts = {
        general = ''"${qtFont uiFont}"'';
        fixed = ''"${qtFont codeFont}"'';
      };
    };
  };

  catppuccin = {
    # Flavour and accent come from the shared catppuccin settings.
    kvantum.enable = true;
    cursors.enable = true;
    # iconTheme above owns the icons, for GTK and Qt alike.
    gtk.icon.enable = false;
  };

  xdg = {
    desktopEntries = {
      plex-desktop = {
        name = "Plex";
        exec = "plex-desktop";
        icon = "plex-desktop";
        terminal = false;
        type = "Application";
        categories = [ "AudioVideo" ];
        settings.StartupWMClass = "tv.plex.Plex";
      };
    };

    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/http" = "google-chrome.desktop";
        "x-scheme-handler/https" = "google-chrome.desktop";
        "video/*" = "mpv.desktop";
      };
    };
  };
}
