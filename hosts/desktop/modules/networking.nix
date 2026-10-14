_: {
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

  services = {
    tailscale.extraSetFlags = [ "--accept-dns=true" ];

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
