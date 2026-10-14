_: {

  system = {
    defaults = {
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };

      # Free Command+Space (symbolic hotkey 64) from Spotlight for vicinae.
      CustomUserPreferences."com.apple.symbolichotkeys".AppleSymbolicHotKeys."64" = {
        enabled = false;
        value = {
          parameters = [
            32
            49
            1048576
          ];
          type = "standard";
        };
      };
    };
  };

}
