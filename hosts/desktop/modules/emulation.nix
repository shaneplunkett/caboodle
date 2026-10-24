{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    eden
    ryubing
    (retroarch.withCores (
      cores: with cores; [
        gambatte
        mgba
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
}
