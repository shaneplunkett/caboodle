{
  palette,
  typography,
  pkgs,
  ...
}:
let
  inherit (palette) withHash;

  pickerStylesheet = pkgs.writeText "hyprland-preview-share-picker.css" ''
    * {
      all: unset;
      color: ${withHash.text};
      font-family: "${typography.ui}";
      font-size: 14px;
    }

    .window {
      margin: 4px;
      border: 1px solid ${withHash.surface1};
      border-radius: 14px;
      background-color: ${withHash.base};
      box-shadow: 0 12px 32px alpha(${withHash.crust}, 0.8);
    }

    tabs {
      padding: 12px 16px 0;
      background-color: ${withHash.mantle};
    }

    tabs > tab {
      margin-right: 6px;
      padding: 8px 14px;
      border-radius: 9px 9px 0 0;
    }

    tabs > tab:hover {
      background-color: ${withHash.surface0};
    }

    tabs > tab:checked {
      background-color: ${withHash.base};
    }

    .tab-label {
      color: ${withHash.subtext0};
      font-weight: 600;
    }

    tabs > tab:checked > .tab-label,
    tabs > tab:focus > .tab-label {
      color: ${withHash.mauve};
    }

    .page {
      padding: 18px;
    }

    flowboxchild > .card,
    button > .card {
      padding: 7px;
      border: 2px solid ${withHash.surface0};
      border-radius: 11px;
      background-color: ${withHash.mantle};
    }

    flowboxchild:hover > .card,
    button:hover > .card {
      border-color: ${withHash.surface2};
      background-color: ${withHash.surface0};
    }

    flowboxchild:active > .card,
    flowboxchild:selected > .card,
    flowboxchild:focus > .card,
    button:active > .card,
    button:selected > .card,
    button:focus > .card {
      border-color: ${withHash.mauve};
      background-color: ${withHash.surface0};
    }

    .card-loading {
      opacity: 0.65;
    }

    .image {
      border-radius: 7px;
    }

    .image-label {
      padding: 7px 4px 2px;
      color: ${withHash.subtext1};
      font-size: 12px;
      font-weight: 600;
    }

    .region-button {
      margin: 14px;
      padding: 12px 18px;
      border-radius: 9px;
      background-color: ${withHash.mauve};
      color: ${withHash.crust};
      font-weight: 700;
    }

    .region-button:hover,
    .region-button:focus {
      background-color: ${withHash.pink};
    }

    .restore-button {
      margin: 0 18px 18px;
      padding: 8px 10px;
      color: ${withHash.subtext0};
    }

    .restore-button check {
      min-width: 16px;
      min-height: 16px;
      margin-right: 9px;
      border: 1px solid ${withHash.overlay0};
      border-radius: 5px;
      background-color: ${withHash.surface0};
    }

    .restore-button check:checked {
      border-color: ${withHash.mauve};
      background-color: ${withHash.mauve};
      color: ${withHash.crust};
      -gtk-icon-source: -gtk-icontheme("object-select-symbolic");
    }
  '';

  pickerConfig = (pkgs.formats.yaml { }).generate "hyprland-preview-share-picker.yaml" {
    stylesheets = [ "${pickerStylesheet}" ];
    default_page = "windows";
    hide_token_restore = true;
    window = {
      width = 1100;
      height = 620;
    };
    image = {
      resize_size = 320;
      widget_size = 190;
    };
    windows = {
      min_per_row = 3;
      max_per_row = 4;
      clicks = 1;
      spacing = 12;
    };
    outputs = {
      clicks = 1;
      spacing = 8;
      show_label = true;
      respect_output_scaling = true;
    };
  };
in
{
  home.packages = [ pkgs.hyprland-preview-share-picker ];

  xdg.configFile = {
    "hypr/xdph.conf".text = ''
      screencopy {
        allow_token_by_default = true
        custom_picker_binary = ${pkgs.hyprland-preview-share-picker}/bin/hyprland-preview-share-picker
      }
    '';
    "hyprland-preview-share-picker/config.yaml".source = pickerConfig;
  };
}
