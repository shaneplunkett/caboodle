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
  roundhog = pkgs.callPackage ./roundhog { };
  tavily-cli = pkgs.callPackage ./tavily-cli { };
  vex-code = pkgs.callPackage ./vex-code { src = vexCodeSrc; };
  xcodebuild-nvim = pkgs.callPackage ./xcodebuild-nvim { };
}
// optionalAttrs isLinux {
  bluebubbles-themed = pkgs.callPackage ./bluebubbles-themed {
    palette = import ../home/palette.nix;
  };
  cosmic-ext-ctl-v2 = pkgs.callPackage ./cosmic-ext-ctl-v2 { };
  hyprland-preview-share-picker = pkgs.callPackage ./hyprland-preview-share-picker { };
}
// optionalAttrs isDarwin {
  bluebubbles-server = pkgs.callPackage ./bluebubbles-server { };
}
// optionalAttrs (isDarwin || isX86Linux) {
  slack-themed = pkgs.callPackage ./slack-themed { };
}
// optionalAttrs isX86Linux {
  linear-desktop = pkgs.callPackage ./linear-desktop {
    typography = import ../home/typography.nix;
  };
  opendeck = pkgs.callPackage ./opendeck { };
  bambu-studio-bin = pkgs.callPackage ./bambu-studio-bin { };
  waydroid-houdini = pkgs.callPackage ./waydroid-houdini { };
}
