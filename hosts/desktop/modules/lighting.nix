{ lib, pkgs, ... }:
let
  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
in
{
  boot.kernelModules = [
    "i2c-dev"
    "i2c-piix4"
  ];

  services.udev.packages = [ pkgs.openrgb ];
  environment.systemPackages = [ pkgs.openrgb ];

  systemd.services.lights-off = {
    description = "Switch off the RAM, motherboard and GPU lighting";
    after = [ "multi-user.target" ] ++ sleepTargets;
    wantedBy = [ "multi-user.target" ] ++ sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "lights-off";
      ExecStart = lib.escapeShellArgs [
        (lib.getExe pkgs.openrgb)
        "--config"
        "/var/lib/lights-off"
        "--noautoconnect"
        "--device"
        "Kingston"
        "--mode"
        "direct"
        "--color"
        "000000"
        "--device"
        "ASRock"
        "--mode"
        "off"
        "--device"
        "Sapphire"
        "--mode"
        "off"
      ];
    };
  };
}
