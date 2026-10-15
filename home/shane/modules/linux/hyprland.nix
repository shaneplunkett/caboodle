{
  lib,
  palette,
  shell,
  ...
}:
let
  inherit (palette) hyprRgba;
  inherit (lib.generators) mkLuaInline;

  mod = "SUPER";
  terminal = "ghostty";

  primaryWorkspaceGaps = {
    top = 50;
    right = 70;
    bottom = 110;
    left = 70;
  };

  bind = keys: dispatcher: {
    _args = [
      keys
      (mkLuaInline dispatcher)
    ];
  };
  bindOpts = keys: dispatcher: opts: {
    _args = [
      keys
      (mkLuaInline dispatcher)
      opts
    ];
  };
  exec = cmd: ''hl.dsp.exec_cmd("${cmd}")'';

  workspaceKeys = [
    {
      key = "1";
      ws = 1;
    }
    {
      key = "2";
      ws = 2;
    }
    {
      key = "A";
      ws = 3;
    }
    {
      key = "B";
      ws = 4;
    }
    {
      key = "T";
      ws = 5;
    }
    {
      key = "I";
      ws = 6;
    }
    {
      key = "S";
      ws = 7;
    }
    {
      key = "M";
      ws = 8;
    }
    {
      key = "9";
      ws = 9;
    }
    {
      key = "O";
      ws = 10;
    }
    {
      key = "G";
      ws = 11;
    }
    {
      key = "E";
      ws = 12;
    }
  ];

  workspaceApps = {
    "3" = [
      "^t3code$"
      "^chatgpt$"
      "^claude(-desktop)?$"
    ];
    "4" = [ "^google-chrome$" ];
    "5" = [ "^com\\.mitchellh\\.ghostty$" ];
    "6" = [ "^linear$" ];
    "7" = [
      "^signal$"
      "(?i)^slack$"
      "^ferdium$"
      "^vesktop$"
      "^bluebubbles$"
    ];
    "8" = [
      "^com\\.edde746\\.plezy$"
      "^YouTube Music Desktop App$"
    ];
    "10" = [ "^md\\.Obsidian$" ];
    "11" = [
      "(?i)^steam$"
      "^steam_app_.*$"
    ];
    "12" = [ "^mail$" ];
  };

  appWorkspaceRules = lib.concatLists (
    lib.mapAttrsToList (
      ws: classes:
      map (class: {
        match.class = class;
        workspace = ws;
      }) classes
    ) workspaceApps
  );

  workspaceBinds = lib.concatMap (
    { key, ws }:
    [
      (bind "${mod} + ${key}" "hl.dsp.focus({ workspace = ${toString ws} })")
      (bind "${mod} + SHIFT + ${key}" "hl.dsp.window.move({ workspace = ${toString ws}, follow = true })")
    ]
  ) workspaceKeys;

  directionBinds =
    lib.concatMap
      (dir: [
        (bind "${mod} + ${dir.key}" ''hl.dsp.focus({ direction = "${dir.d}" })'')
        (bind "${mod} + SHIFT + ${dir.key}" ''hl.dsp.window.move({ direction = "${dir.d}" })'')
      ])
      [
        {
          key = "h";
          d = "l";
        }
        {
          key = "l";
          d = "r";
        }
        {
          key = "k";
          d = "u";
        }
        {
          key = "j";
          d = "d";
        }
      ];
in
{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "lua";
    # Noctalia runs as a user service, outside the login session's scope; it
    # finds its logind session (lock-session, sleep hooks) via this variable.
    systemd.variables = lib.mkOptionDefault [ "XDG_SESSION_ID" ];
    settings = {
      bind = [
        (bind "${mod} + SHIFT + Q" "hl.dsp.window.close()")
        (bind "${mod} + RETURN" (exec terminal))
        (bind "${mod} + SHIFT + W" (exec "hyprctl dispatch togglehidden"))
        (bind "${mod} + SHIFT + F" "hl.dsp.window.float()")

        (bindOpts "${mod} + mouse:272" "hl.dsp.window.drag()" { mouse = true; })
        (bindOpts "${mod} + mouse:273" "hl.dsp.window.resize()" { mouse = true; })
      ]
      ++ workspaceBinds
      ++ directionBinds
      ++ [
        (bind "${mod} + space" (exec "vicinae toggle"))
        (bind "${mod} + V" (exec "vicinae deeplink vicinae://launch/clipboard/history?toggle=true"))
        # T3 SnapShots: fires the GlobalShortcuts action T3 registers through xdph.
        (bind "${mod} + SHIFT + 3" ''hl.dsp.global("com.t3tools.T3Code:capture-window")'')
      ]
      ++ lib.optionals (shell == "noctalia") [
        (bind "${mod} + N" (exec "noctalia msg panel-toggle control-center"))
        (bind "${mod} + SHIFT + 4" (exec "noctalia msg screenshot-region"))
        (bind "${mod} + SHIFT + 5" (exec "noctalia msg plugin noctalia/screen_recorder:service all toggle"))
      ];

      curve = [
        {
          _args = [
            "easeout"
            {
              type = "bezier";
              points = [
                [
                  0.25
                  0.1
                ]
                [
                  0.25
                  1.0
                ]
              ];
            }
          ];
        }
      ];

      animation = [
        {
          leaf = "windows";
          enabled = true;
          speed = 3;
          bezier = "easeout";
          style = "gnomed";
        }
        {
          leaf = "windowsOut";
          enabled = true;
          speed = 3;
          bezier = "easeout";
          style = "gnomed";
        }
        {
          leaf = "fade";
          enabled = true;
          speed = 3;
          bezier = "easeout";
        }
        {
          leaf = "border";
          enabled = true;
          speed = 10;
          bezier = "easeout";
        }
        {
          leaf = "workspaces";
          enabled = true;
          speed = 2;
          bezier = "easeout";
          style = "slide";
        }
      ];

      window_rule = [
        {
          match.class = "^com\\.example\\.launcher$";
          float = true;
          size = [
            500
            430
          ];
        }
        {
          match.title = "^Plex.*$";
          opaque = true;
        }
        {
          match.class = "^com\\.system76\\.CosmicFiles$";
          float = true;
          size = [
            1100
            700
          ];
        }
        {
          match.title = "^.*Bluetooth Devices$";
          float = true;
          size = [
            1100
            700
          ];
        }
        # The Bitwarden extension's Chrome popout (login, passkeys). Tiled, it
        # fights the layout over its size and drops keystrokes.
        {
          match.class = "^chrome-nngceckbapebfimnlniiiahkandclblb-.*$";
          float = true;
          center = true;
          size = [
            480
            700
          ];
        }
        {
          match.title = "^.*Volume Control$";
          float = true;
          size = [
            1100
            700
          ];
        }
      ]
      ++ appWorkspaceRules;

      # Upstream's recommended rule: Noctalia animates its own surfaces.
      layer_rule = lib.optionals (shell == "noctalia") [
        {
          name = "noctalia";
          match.namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$";
          no_anim = true;
          ignore_alpha = 0.5;
          blur = true;
          blur_popups = true;
        }
      ];

      monitor = [
        {
          output = "DP-2";
          mode = "3840x2160@240";
          position = "0x0";
          scale = 1.5;
          vrr = 2;
        }
        {
          output = "HDMI-A-1";
          mode = "2560x1440@60";
          position = "-3000x0";
          scale = 1;
          transform = 3;
        }
      ];

      workspace_rule =
        map
          (ws: {
            workspace = toString ws;
            monitor = "DP-2";
            gaps_out = primaryWorkspaceGaps;
            default = ws == 1;
          })
          (
            lib.range 1 8
            ++ [
              10
              11
              12
            ]
          )
        ++ [
          {
            workspace = "9";
            monitor = "HDMI-A-1";
            default = true;
          }
        ];

      env = [
        {
          _args = [
            "STEAM_FORCE_DESKTOPUI_SCALING"
            "1.25"
          ];
        }
        {
          _args = [
            "GDK_SCALE"
            "2"
          ];
        }
        {
          _args = [
            "XCURSOR_SIZE"
            "48"
          ];
        }
      ];

      config = {
        general = {
          border_size = 2;
          gaps_in = 5;
          gaps_out = 50;
          resize_on_border = true;

          col = {
            active_border = {
              colors = [
                hyprRgba.mauve
                hyprRgba.lavender
              ];
              angle = 45;
            };
            inactive_border = hyprRgba.surface2;
          };
        };

        decoration = {
          rounding = 10;
          border_part_of_window = false;

          blur = {
            enabled = true;
            size = 8;
            passes = 1;
            new_optimizations = true;
          };

          shadow = {
            enabled = true;
            range = 4;
            render_power = 3;
            color = hyprRgba.base;
            color_inactive = hyprRgba.mantle;
          };
        };

        animations.enabled = true;

        group = {
          col = {
            border_active = hyprRgba.green;
            border_inactive = hyprRgba.surface2;
          };
          groupbar = {
            font_size = 10;
            gradients = false;
            col = {
              active = hyprRgba.mauve;
              inactive = hyprRgba.surface0;
            };
          };
        };

        xwayland.force_zero_scaling = true;
      };
    };
  };
}
