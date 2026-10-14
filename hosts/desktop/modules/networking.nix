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

  # MagicDNS. Without resolved, tailscaled overwrites /etc/resolv.conf and
  # fights NetworkManager (what broke this in March). With it, tailscaled
  # registers 100.100.100.100 on tailscale0: .ts.net names resolve there and
  # everything else is forwarded to Technitium, the tailnet's global resolver.
  # If Tailscale is down, the LAN link's Technitium servers answer instead.
  services = {
    tailscale.extraSetFlags = [ "--accept-dns=true" ];

    resolved = {
      enable = true;
      settings.Resolve = {
        # Avahi already owns mDNS on 5353.
        MulticastDNS = false;
        LLMNR = false;
        # Never fall back to public resolvers behind Technitium's back.
        FallbackDNS = [ ];
      };
    };
  };
}
