{ lib, ... }:
{
  options.homelab.tailscale = {
    enable = lib.mkEnableOption "joining the tailnet" // {
      default = true;
    };
    subnetRouter = lib.mkEnableOption "advertising the LAN to the tailnet";
  };
}
