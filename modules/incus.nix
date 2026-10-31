{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/virtualisation/lxc-container.nix")
    ./guest.nix
  ];

  networking = {
    hostName = "";
    dhcpcd.enable = false;
    useDHCP = false;
    useHostResolvConf = false;
    useNetworkd = true;
  };

  systemd.network.wait-online.ignoredInterfaces = [ "tailscale0" ];

  systemd.network.networks = {
    "50-eth0" = {
      matchConfig.Name = "eth0";
      networkConfig.DHCP = "ipv4";
      linkConfig.RequiredForOnline = "routable";
    };
  }
  // lib.listToAttrs (
    lib.imap1 (
      i: vlan:
      lib.nameValuePair "50-eth${toString i}" {
        matchConfig.Name = "eth${toString i}";
        address = [ vlan.address ];
        networkConfig = {
          DHCP = "no";
          IPv6AcceptRA = false;
        };
        linkConfig.RequiredForOnline = "no";
      }
    ) (lib.optionals (config.homelab.guest != null) config.homelab.guest.vlans)
  );
}
