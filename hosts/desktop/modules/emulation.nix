{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    eden
    ryubing
    fusee-nano
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
