{
  pkgs,
  vexCodeSrc,
  isLinux ? false,
  isDarwin ? false,
  isX86Linux ? false,
}:
let
  optionalAttrs = condition: attrs: if condition then attrs else { };
in
{
  browserbase-cli = pkgs.callPackage ./browserbase-cli { };
  langsmith-cli = pkgs.callPackage ./langsmith-cli { };
  roundhog = pkgs.callPackage ./roundhog { };
  tavily-cli = pkgs.callPackage ./tavily-cli { };
  todoist-cli = pkgs.callPackage ./todoist-cli { };
  unifi-cli = pkgs.callPackage ./unifi-cli { };
  vex-code = pkgs.callPackage ./vex-code { src = vexCodeSrc; };
  xcodebuild-nvim = pkgs.callPackage ./xcodebuild-nvim { };
}
// optionalAttrs isLinux {
  bluebubbles = pkgs.callPackage ./bluebubbles { };
  bluebubbles-themed = pkgs.callPackage ./bluebubbles-themed {
    palette = import ../home/palette.nix;
  };
  cosmic-ext-ctl-v2 = pkgs.callPackage ./cosmic-ext-ctl-v2 { };
  hyprland-preview-share-picker = pkgs.callPackage ./hyprland-preview-share-picker { };
}
// optionalAttrs isDarwin {
  bluebubbles-server = pkgs.callPackage ./bluebubbles-server { };
}
// optionalAttrs isX86Linux {
  linear-desktop = pkgs.callPackage ./linear-desktop {
    typography = import ../home/typography.nix;
  };
  slack-themed = pkgs.callPackage ./slack-themed { };
  orca-studio = pkgs.callPackage ./orca-studio { };
  shadps4-cache-fixed = pkgs.callPackage ./shadps4-cache-fixed { };
  waydroid-houdini = pkgs.callPackage ./waydroid-houdini { };
  ytmdesktop-bin = pkgs.callPackage ./ytmdesktop-bin { };
}
