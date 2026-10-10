{ nodes, pkgs, ... }: {
  services.blocky = {
    enable = true;
    settings = {
      ports = {
        dns = 53;
        http = 4000;
      };
      upstreams = {
        strategy = "strict";
        timeout = "3s";
        groups.default = [
          "127.0.0.1:5335"
          "tcp-tls:9.9.9.9:853#dns.quad9.net"
          "tcp-tls:1.1.1.1:853#cloudflare-dns.com"
        ];
      };
      clientLookup.upstream = "127.0.0.1:5335";
      caching = {
        prefetching = true;
        minTime = "5m";
      };
      blocking = {
        denylists.ads = [
          "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
          "https://big.oisd.nl/domainswild"
        ];
        allowlists.ads = [
          ''
            local
            localhost
          ''
        ];
        clientGroupsBlock.default = [ "ads" ];
        blockType = "nxDomain";
        loading = {
          strategy = "fast";
          downloads = {
            timeout = "2m";
            attempts = 5;
            cooldown = "10s";
          };
        };
      };
      customDNS = {
        mapping."shaneplunkett.com" = nodes.ingress.config.homelab.lanAddress;
        zone = ''
          $ORIGIN shaneplunkett.com.
          redbook 3600 CNAME red-book-5nn.pages.dev.
        '';
      };
      prometheus.enable = true;
      queryLog.type = "console";
    };
  };
  systemd.services.blocky = {
    after = [ "unbound.service" ];
    wants = [ "unbound.service" ];
  };
  services.resolved.enable = false;
  environment.systemPackages = [ pkgs.dnsutils ];
  networking.firewall = {
    allowedTCPPorts = [
      53
      4000
    ];
    allowedUDPPorts = [ 53 ];

  };
}
