{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.homelab.emulation) root;

  retroarchCores = {
    Gambatte = [
      "gb"
      "gbc"
    ];
    mGBA = [
      "gb"
      "gbc"
      "gba"
    ];
    "melonDS DS" = [ "nds" ];
  };

  retroarchAutoconfig = pkgs.symlinkJoin {
    name = "retroarch-autoconfig";
    paths = [
      "${pkgs.retroarch-joypad-autoconfig}/share/libretro/autoconfig"
      (pkgs.writeTextDir "udev/Steam Virtual Gamepad.cfg" ''
        input_driver = "udev"
        input_device = "Microsoft X-Box 360 pad 0"
        input_device_display_name = "Steam Virtual Gamepad"
        input_vendor_id = "10462"
        input_product_id = "4607"
        input_b_btn = "0"
        input_a_btn = "1"
        input_y_btn = "2"
        input_x_btn = "3"
        input_l_btn = "4"
        input_r_btn = "5"
        input_select_btn = "6"
        input_start_btn = "7"
        input_menu_toggle_btn = "8"
        input_l3_btn = "9"
        input_r3_btn = "10"
        input_up_btn = "h0up"
        input_down_btn = "h0down"
        input_left_btn = "h0left"
        input_right_btn = "h0right"
        input_l2_axis = "+2"
        input_r2_axis = "+5"
        input_l_x_plus_axis = "+0"
        input_l_x_minus_axis = "-0"
        input_l_y_plus_axis = "+1"
        input_l_y_minus_axis = "-1"
        input_r_x_plus_axis = "+3"
        input_r_x_minus_axis = "-3"
        input_r_y_plus_axis = "+4"
        input_r_y_minus_axis = "-4"
      '')
    ];
  };

  ppssppShoulders = pkgs.writeText "ppsspp-shoulders.json" (
    builtins.toJSON {
      L = "1-45,10-193";
      R = "1-51,10-192";
    }
  );

  steamRomManagerParsers = [
    {
      system = "gb";
      title = "Game Boy";
      exe = "retroarch";
      args = "-L gambatte";
      extensions = ".gb|.GB";
    }
    {
      system = "gbc";
      title = "Game Boy Color";
      exe = "retroarch";
      args = "-L gambatte";
      extensions = ".gbc|.GBC";
    }
    {
      system = "gba";
      title = "Game Boy Advance";
      exe = "retroarch";
      args = "-L mgba";
      extensions = ".gba|.GBA";
    }
    {
      system = "nds";
      title = "Nintendo DS";
      exe = "retroarch";
      args = "-L melondsds";
      extensions = ".nds|.NDS";
    }
    {
      system = "psp";
      title = "PSP";
      exe = "ppsspp";
      args = "";
      extensions = ".iso|.ISO|.cso|.CSO";
    }
    {
      system = "n3ds";
      title = "Nintendo 3DS";
      exe = "azahar";
      args = "-f";
      extensions = ".3ds|.3DS|.cci|.CCI|.cxi|.CXI";
    }
    {
      system = "switch";
      title = "Nintendo Switch";
      exe = "eden";
      args = "-f -g";
      extensions = ".nsp|.NSP|.xci|.XCI";
    }
  ];
in
{
  options.homelab.emulation.root = lib.mkOption {
    type = lib.types.str;
    description = "The folder holding roms, saves and bios, each with a folder per system. ~/Emulation links to it.";
  };

  config = {
    environment.systemPackages = with pkgs; [
      azahar
      eden
      ryubing
      vita3k
      steam-rom-manager
      (retroarch-bare.wrapper {
        cores = with libretro; [
          gambatte
          mgba
          melondsds
        ];
        settings.joypad_autoconfig_dir = "${retroarchAutoconfig}";
      })
      ppsspp
      (fusee-nano.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./fusee-nano-discard-delay.patch ];
      }))
    ];

    services.udev.packages = [
      (pkgs.writeTextFile {
        name = "nintendo-switch-udev-rules";
        destination = "/lib/udev/rules.d/70-nintendo-switch.rules";
        text = ''
          SUBSYSTEM=="usb", ATTRS{idVendor}=="0955", ATTRS{idProduct}=="7321", TAG+="uaccess"
          SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", ATTRS{idProduct}=="3000", TAG+="uaccess"
        '';
      })
    ];

    home-manager.users.shane =
      { config, lib, ... }:
      let
        emulation = "${config.home.homeDirectory}/Emulation";
        noArtwork = lib.genAttrs [
          "tall"
          "long"
          "hero"
          "logo"
          "icon"
        ] (_: null);
        steamRomManagerConfig = pkgs.writeText "userConfigurations.json" (
          builtins.toJSON (
            map (parser: {
              parserType = "Glob";
              configTitle = parser.title;
              parserId = "caboodle-${parser.system}";
              version = 29;
              disabled = false;
              steamDirectory = "${config.home.homeDirectory}/.local/share/Steam";
              romDirectory = "${emulation}/roms/${parser.system}";
              steamCategories = [ parser.title ];
              executable = {
                path = "/run/current-system/sw/bin/${parser.exe}";
                shortcutPassthrough = false;
                appendArgsToExecutable = true;
              };
              executableArgs = lib.concatStringsSep " " (
                lib.filter (arg: arg != "") [
                  parser.args
                  "\"\${filePath}\""
                ]
              );
              executableModifier = "\"\${exePath}\"";
              startInDirectory = "";
              titleModifier = "\${/\\s*(\\(.*?\\)|\\[.*?\\])/g|\${title}|}";
              steamInputEnabled = "1";
              parserInputs.glob = "\${title}@(${parser.extensions})";
              fuzzyMatch = {
                replaceDiacritics = true;
                removeCharacters = true;
                removeBrackets = true;
              };
              userAccounts.specifiedAccounts = [ "Global" ];
              titleFromVariable = {
                limitToGroups = [ ];
                skipFileIfVariableWasNotFound = false;
                caseInsensitiveVariables = false;
              };
              sortAsFromVariable.limitToGroups = [ ];
              imagePool = "\${finalTitle}";
              drmProtect = false;
              defaultImage = noArtwork;
              localImages = noArtwork;
              overlayImages = noArtwork;
              onlineImageQueries = [ "\${finalTitle}" ];
              imageProviders = [
                "sgdb"
                "steamCDN"
              ];
              imageProviderAPIs.sgdb = {
                nsfw = false;
                humor = false;
                styles = [ ];
                stylesHero = [ ];
                stylesLogo = [ ];
                stylesIcon = [ ];
                imageMotionTypes = [ "static" ];
                sizes = [ ];
                sizesHero = [ ];
                sizesIcon = [ ];
              };
              controllers = { };
              group = "";
            }) steamRomManagerParsers
          )
        );
        link = path: { source = config.lib.file.mkOutOfStoreSymlink "${emulation}/${path}"; };
        retroarchOverrides = lib.concatMapAttrs (
          core: systems:
          lib.genAttrs' systems (
            system:
            lib.nameValuePair ".config/retroarch/config/${core}/${system}.cfg" {
              text = ''
                savefile_directory = "${emulation}/saves/${system}"
                savestate_directory = "${emulation}/saves/${system}/states"
              '';
            }
          )
        ) retroarchCores;
      in
      {
        home.file = {
          Emulation.source = config.lib.file.mkOutOfStoreSymlink root;
          ".config/ppsspp/PSP/SAVEDATA" = link "saves/psp";
          ".local/share/eden/nand/user/save" = link "saves/switch/eden";
          ".local/share/eden/keys/prod.keys" = link "bios/switch/prod.keys";
          ".local/share/eden/keys/title.keys" = link "bios/switch/title.keys";
          ".config/Ryujinx/bis/user/save" = link "saves/switch/ryubing/save";
          ".config/Ryujinx/bis/user/saveMeta" = link "saves/switch/ryubing/saveMeta";
          ".config/Ryujinx/system/prod.keys" = link "bios/switch/prod.keys";
          ".config/Ryujinx/system/title.keys" = link "bios/switch/title.keys";
          ".local/share/azahar-emu/sysdata/boot9.bin" = link "bios/n3ds/boot9.bin";
        }
        // retroarchOverrides;

        home.activation.steamRomManager = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run install -Dm644 ${steamRomManagerConfig} ${config.xdg.configHome}/steam-rom-manager/userData/userConfigurations.json
        '';

        home.activation.ppssppShoulders = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run ${pkgs.python3}/bin/python3 -I ${./emulator-controls.py} ${config.xdg.configHome}/ppsspp/PSP/SYSTEM/controls.ini ControlMapping ${ppssppShoulders}
        '';
      };
  };
}
