{ modulesPath, ... }:
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

  systemd.network.networks."50-eth0" = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
    linkConfig.RequiredForOnline = "routable";
  };
}
