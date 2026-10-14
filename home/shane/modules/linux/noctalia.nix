# Noctalia v5 shell. Clean slate: v5 defaults plus the handful of things
# that matter. Runtime tweaks from the Settings GUI land in
# ~/.local/state/noctalia/settings.toml and override this file.
{
  config,
  inputs,
  lib,
  palette,
  typography,
  ...
}:
let
  # Palette files key roles as mOnSurfaceVariant; the shared set uses
  # on_surface_variant (the spelling config and the greeter expect).
  paletteKey =
    role:
    "m"
    + lib.concatMapStrings (word: lib.toUpper (lib.substring 0 1 word) + lib.substring 1 (-1) word) (
      lib.splitString "_" role
    );
  wallpapers = "${config.home.homeDirectory}/wallpapers";
in
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    # The loader rejects a palette without a terminal block, despite the docs
    # showing it as optional. Catppuccin Mocha's standard ANSI mapping.
    customPalettes.vex.dark =
      lib.mapAttrs' (role: colour: lib.nameValuePair (paletteKey role) colour) palette.noctaliaRoles
      // {
        terminal = with palette.withHash; {
          background = base;
          foreground = text;
          cursor = rosewater;
          cursorText = base;
          selectionBg = surface2;
          selectionFg = text;
          normal = {
            black = surface1;
            inherit
              red
              green
              yellow
              blue
              ;
            magenta = pink;
            cyan = teal;
            white = subtext1;
          };
          bright = {
            black = surface2;
            inherit
              red
              green
              yellow
              blue
              ;
            magenta = pink;
            cyan = teal;
            white = subtext0;
          };
        };
      };

    settings = {
      accessibility.ui_scale = 1.15;

      shell = {
        font_family = typography.ui;
        avatar_path = "${config.home.homeDirectory}/.face";
        polkit_agent = true;
        # Apps launched from the shell survive the unit restarting on rebuild.
        launch_apps_as_systemd_services = true;
        # Vicinae owns clipboard history.
        clipboard_enabled = false;
        panel = {
          transparency_mode = "glass";
          open_near_click_control_center = true;
        };
      };

      theme = {
        mode = "dark";
        source = "custom";
        custom_palette = "vex";
      };

      bar.main = {
        position = "top";
        monitor."HDMI-A-1".enabled = false;
        thickness = 45;
        scale = 1.1;
        font_weight = 400;
        radius = 20;
        radius_top_left = 0;
        radius_top_right = 0;
        margin_ends = 0;
        panel_overlap = 0;
        capsule = true;
        capsule_thickness = 0.6;

        start = [
          "cpu"
          "ram"
          "media"
          "audio_visualizer"
        ];
        center = [ "workspaces" ];
        end = [
          "tray"
          "tailscale-guard"
          "hassio"
          "network"
          "bluetooth"
          "volume"
          "clock"
          "weather"
          "control-center"
          "notifications"
        ];
      };

      widget = {
        clock.format = "{:%-I:%M %p  %d/%m/%Y}";
        network.show_label = false;
        ram.visualization = "none";
        tailscale-guard.type = "vex/tailscale-guard:bar";
        hassio.type = "pozzoo/hassio:status";
        tray.drawer = true;
        workspaces.style = "focus_hint";
      };

      notification = {
        position = "top_right";
        monitors = [ "DP-2" ];
        layer = "overlay";
        background_opacity = 0.9;
        max_visible = 2;
      };

      wallpaper = {
        directory = wallpapers;
        automation = {
          enabled = true;
          interval_seconds = 300;
          order = "random";
          recursive = true;
        };
      };

      location.address = "Melbourne, Australia";
      weather.enabled = true;

      # The OAuth token lives in Noctalia's state, not here.
      calendar = {
        enabled = true;
        account.personal_google = {
          name = "Calendar";
          type = "google";
        };
      };

      plugins = {
        enabled = [
          "noctalia/screen_recorder"
          "vex/tailscale-guard"
          "pozzoo/hassio"
        ];

        # Declaring any source replaces noctalia's built-in list, so official
        # and community are restated. Later sources win on a shared id; a
        # plugin symlinked into ~/.local/share/noctalia/plugins (`just dev` in
        # the repo) outranks them all.
        source = [
          {
            name = "official";
            kind = "git";
            location = "https://github.com/noctalia-dev/official-plugins";
          }
          {
            name = "community";
            kind = "git";
            location = "https://github.com/noctalia-dev/community-plugins";
          }
          {
            name = "vex";
            kind = "path";
            location = "${inputs.noctalia-plugins}/plugins";
          }
        ];
      };

      # The personal tailnet runs MagicDNS on purpose; the guard leaves it be.
      plugin_settings."vex/tailscale-guard".trusted_profiles = [ "shaneplunkett.github" ];

      # The Home Assistant URL and token are entered in Settings → Plugins, so
      # they land in Noctalia's state file rather than this repo.
    };
  };
}
