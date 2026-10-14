{ pkgs, lib, ... }:
{
  nix.settings = {
    # Keep memory-hungry builds from fanning out into swap pressure.
    cores = 2;
    max-jobs = 1;
  };

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0070", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0fd9", ATTR{idProduct}=="0094", ATTR{power/autosuspend}="-1", ATTR{power/control}="on"
  '';
  systemd.services.usb-hub-reset = {
    description = "Reset USB hub chain for monitor KVM";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
      ExecStart = lib.getExe (
        pkgs.writeShellApplication {
          name = "usb-hub-reset";
          text = ''
            for dev in /sys/bus/usb/devices/*/idVendor; do
              dir=$(dirname "$dev")
              vendor=$(cat "$dev" 2>/dev/null || true)
              product=$(cat "$dir/idProduct" 2>/dev/null || true)
              if [ "$vendor" = "0b05" ] && [ "$product" = "1bd6" ]; then
                devname=$(basename "$dir")
                driver="/sys/bus/usb/drivers/usb"
                if [ -e "$driver/$devname" ]; then
                  echo "Resetting ASUS monitor USB hub: $devname"
                  echo "$devname" > "$driver/unbind" 2>/dev/null || true
                  sleep 2
                  echo "$devname" > "$driver/bind" 2>/dev/null || true
                fi
              fi
            done
          '';
        }
      );
    };
  };
}
