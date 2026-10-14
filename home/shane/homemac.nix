{ ... }:
{

  imports = [
    ./modules/common
    ./modules/darwin
  ];

  home = {
    username = "shane";
    homeDirectory = "/Users/shane";
    stateVersion = "24.11";
    sessionVariables = {
      EDITOR = "nvim";
    };
  };

  # Copy apps rather than symlink them so Spotlight and vicinae index them.
  # Laptop only: the copy needs App Management, which fails over SSH, and
  # mini-server is driven over SSH.
  targets.darwin = {
    copyApps.enable = true;
    linkApps.enable = false;

    # Swap Option and Command on the external keyboard (vendor 12815,
    # product 20548) so its Super key acts as Option for OmniWM. The
    # built-in keyboard already has Option in that spot.
    currentHostDefaults.NSGlobalDomain."com.apple.keyboard.modifiermapping.12815-20548-0" =
      let
        # HID usage codes 0x7000000E2, E3, E6, E7.
        leftOption = 30064771298;
        leftCommand = 30064771299;
        rightOption = 30064771302;
        rightCommand = 30064771303;
        swap = src: dst: {
          HIDKeyboardModifierMappingSrc = src;
          HIDKeyboardModifierMappingDst = dst;
        };
      in
      [
        (swap leftOption leftCommand)
        (swap leftCommand leftOption)
        (swap rightOption rightCommand)
        (swap rightCommand rightOption)
      ];
  };

  programs.home-manager.enable = true;
}
