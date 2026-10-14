_: {
  services.sunshine = {
    enable = true;
    autoStart = true;

    # Hyprland's wlroots capture path works without the broad CAP_SYS_ADMIN
    # capability required by KMS capture.
    capSysAdmin = false;
    openFirewall = false;

    settings = {
      capture = "wlr";
      encoder = "vaapi";
      adapter_name = "/dev/dri/renderD128";

      # Sunshine reports the primary DP-2 display as output ID 0.
      output_name = 0;

      # Remote access goes through Tailscale rather than router port forwards.
      upnp = "disabled";
      origin_web_ui_allowed = "pc";
      lan_encryption_mode = 2;
      wan_encryption_mode = 2;
    };
  };

  # The pinned Sunshine package loads uhid but omits upstream's udev rules.
  # Keep its virtual-controller devices accessible through the same group as
  # /dev/uinput so DS5, Xbox, and Switch controller emulation all work.
  services.udev.extraRules = ''
    KERNEL=="uhid", GROUP="uinput", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{name}=="Sunshine PS5 (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine X-Box One (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine gamepad (virtual) motion sensors*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine Nintendo (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine PS5 (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
  '';

  # Sunshine's package advertises this through modules-load.d, but NixOS does
  # not consume package-provided modules-load files during early boot.
  boot.kernelModules = [ "uhid" ];

  # Moonlight's streaming ports are exposed only on the wired home LAN.
  # tailscale0 is already trusted by networking.nix for remote streaming.
  networking.firewall.interfaces.enp10s0 = {
    allowedTCPPorts = [
      47984
      47989
      48010
    ];
    allowedUDPPorts = [
      47998
      47999
      48000
      48002
      48010
    ];
  };

  # Sunshine uses uinput for remote keyboard, mouse, and controller events.
  users.users.shane.extraGroups = [ "uinput" ];
}
