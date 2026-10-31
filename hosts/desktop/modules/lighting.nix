{
  config,
  lib,
  nodes,
  pkgs,
  ...
}:
let
  cfg = config.services.hardware.openrgb;
in
{
  services.hardware.openrgb = {
    enable = true;
    motherboard = "amd";
  };

  systemd.services.openrgb = {
    serviceConfig.ExecStart = lib.mkForce (
      lib.escapeShellArgs [
        (lib.getExe cfg.package)
        "--server"
        "--server-host"
        "0.0.0.0"
        "--server-port"
        cfg.server.port
      ]
    );
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="0b05", ATTRS{idProduct}=="1b2b", RUN+="${lib.getExe' pkgs.systemd "systemctl"} --no-block try-restart openrgb.service"
  '';

  networking.firewall.extraInputRules = ''
    ip saddr ${nodes.home.config.homelab.lanAddress} tcp dport ${toString cfg.server.port} accept
  '';
}
