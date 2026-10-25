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
      (retroarch.withCores (
        cores: with cores; [
          gambatte
          mgba
          melondsds
        ]
      ))
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
              titleModifier = "\${fuzzyTitle}";
              steamInputEnabled = "1";
              parserInputs.glob = "\${title}@(${parser.extensions})";
              fuzzyMatch = {
                replaceDiacritics = true;
                removeCharacters = true;
                removeBrackets = true;
              };
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
      };
  };
}
