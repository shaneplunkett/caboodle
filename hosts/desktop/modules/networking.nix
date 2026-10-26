{ config, ... }:
{
  networking = {
    networkmanager.enable = true;
    modemmanager.enable = false;

    firewall = {
      enable = true;
      trustedInterfaces = [ "tailscale0" ];
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
    };
  };

  homelab.portForwards.tailscale-desktop = {
    inherit (config.services.tailscale) port;
    protocol = "udp";
  };

  services = {
    tailscale = {
      extraSetFlags = [ "--accept-dns=true" ];
      openFirewall = true;
    };

    resolved = {
      enable = true;
      settings.Resolve = {
        MulticastDNS = false;
        LLMNR = false;
        FallbackDNS = [ ];
      };
    };
  };
}
