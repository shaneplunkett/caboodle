_: {
  system = {
    defaults = {
      SoftwareUpdate = {
        AutomaticallyInstallMacOSUpdates = true;
      };

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

  networking.applicationFirewall = {
    enable = true;
    blockAllIncoming = false;
    allowSigned = true;
    allowSignedApp = true;
    enableStealthMode = true;
  };
}
