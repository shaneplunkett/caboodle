{
  pkgs,
  lib,
  typography,
  ...
}:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;

  fishCommand = "${lib.getExe pkgs.fish} --login --interactive";
in
{
  programs.ghostty = {
    enable = true;
    package = lib.mkIf isDarwin null;
    enableBashIntegration = false;
    enableFishIntegration = true;
    enableZshIntegration = false;

    settings = {
      font-family = typography.code;
      font-size = if isDarwin then 21 else 14;
      command = fishCommand;
      shell-integration = "fish";
      shell-integration-features = "cursor,no-sudo,title";
      confirm-close-surface = false;
    }
    // lib.optionalAttrs isDarwin {
      macos-titlebar-style = "hidden";
      macos-non-native-fullscreen = true;
      window-save-state = "never";
    };
  };
}
