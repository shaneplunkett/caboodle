{ pkgs, ... }:
{
  programs = {
    neovim.defaultEditor = true;
    hyprland = {
      enable = true;
      xwayland.enable = true;
    };
    appimage = {
      enable = true;
      binfmt = true;
    };
    # Run prebuilt dynamically-linked binaries (PyPI wheels like ruff,
    # pre-commit hook envs, vendor CLIs) without per-binary patchelf.
    nix-ld = {
      enable = true;
      # chrome-headless-shell's runtime deps. T3 Code downloads Google's
      # prebuilt shell into ~/.t3/tools for html_preview and has no setting
      # to use a Nix-built browser instead.
      libraries = with pkgs; [
        alsa-lib
        at-spi2-core
        dbus
        expat
        glib
        libgbm
        libx11
        libxcb
        libxcomposite
        libxdamage
        libxext
        libxfixes
        libxkbcommon
        libxrandr
        nspr
        nss
      ];
    };
    # Backend for Noctalia's noctalia/screen_recorder plugin.
    gpu-screen-recorder.enable = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-cosmic
    ];
    # Hyprland's own routing, except open/save dialogs go to COSMIC's portal:
    # a standalone picker, themed Catppuccin in home/shane/modules/linux/cosmic.nix.
    config.hyprland = {
      default = [
        "hyprland"
        "gtk"
      ];
      "org.freedesktop.impl.portal.FileChooser" = [ "cosmic" ];
    };
  };
}
