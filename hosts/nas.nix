{ config, ... }:
{
  imports = [
    ../modules/services/nas
  ];

  homelab.lanAddress = config.homelab.devices.unraid.ip;
  homelab.tailscale.enable = false;
  homelab.nas.readOnly = true;
}
