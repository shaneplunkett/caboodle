{
  config,
  lib,
  nodes,
  ...
}:
let
  cfg = config.services.hardware.openrgb;
  openrgb = lib.getExe cfg.package;
  sleepTargets = [
    "suspend.target"
    "hibernate.target"
    "hybrid-sleep.target"
    "suspend-then-hibernate.target"
  ];
  sendToServer =
    args:
    lib.escapeShellArgs (
      [
        openrgb
        "--nodetect"
      ]
      ++ args
    );
in
{
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  systemd.services.openrgb = {
    after = [ "usb-hub-reset.service" ];
    serviceConfig.ExecStart = lib.mkForce (
      lib.escapeShellArgs [
        openrgb
        "--server"
        "--server-host"
        "0.0.0.0"
        "--server-port"
        cfg.server.port
      ]
    );
  };

  networking.firewall.extraInputRules = ''
    ip saddr ${nodes.home.config.homelab.lanAddress} tcp dport ${toString cfg.server.port} accept
  '';

  systemd.services.lights-off = {
    description = "Switch off the desktop's lighting through the OpenRGB server";
    bindsTo = [ "openrgb.service" ];
    after = [ "openrgb.service" ] ++ sleepTargets;
    wantedBy = [ "openrgb.service" ] ++ sleepTargets;
    serviceConfig = {
      Type = "oneshot";
      Restart = "on-failure";
      RestartSec = 5;
      ExecStart = [
        (sendToServer [
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
        ])
        "-${
          sendToServer [
            "--device"
            "PG32UCDM"
            "--mode"
            "direct"
            "--color"
            "000000"
          ]
        }"
      ];
    };
  };
}
