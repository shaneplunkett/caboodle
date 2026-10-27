{ config, lib, ... }:
let
  cfg = config.homelab.incus;
in
{
  options.homelab.incus = {
    uplink = lib.mkOption {
      type = lib.types.str;
      description = "The network port the guests' bridge sits on, so guests are on the LAN beside the host.";
    };

    mac = lib.mkOption {
      type = lib.types.str;
      description = "The bridge's MAC, the uplink's own, so the host keeps its UniFi reservation.";
    };

    storage = lib.mkOption {
      type = lib.types.str;
      description = "The block device Incus turns into an LVM thin pool for the guests' disks.";
    };
  };

  config = {
    networking = {
      useNetworkd = true;
      useDHCP = false;
      nftables.enable = true;
    };

    systemd.network = {
      netdevs.br0.netdevConfig = {
        Kind = "bridge";
        Name = "br0";
        MACAddress = cfg.mac;
      };
      networks = {
        uplink = {
          matchConfig.Name = cfg.uplink;
          networkConfig.Bridge = "br0";
        };
        br0 = {
          matchConfig.Name = "br0";
          networkConfig.DHCP = "ipv4";
        };
      };
    };

    virtualisation.incus = {
      enable = true;
      preseed = {
        storage_pools = [
          {
            name = "default";
            driver = "lvm";
            config = {
              source = cfg.storage;
              "lvm.vg_name" = "incus";
            };
          }
        ];
        profiles = [
          {
            name = "default";
            devices = {
              eth0 = {
                name = "eth0";
                type = "nic";
                nictype = "bridged";
                parent = "br0";
              };
              root = {
                type = "disk";
                path = "/";
                pool = "default";
              };
            };
          }
        ];
      };
    };
  };
}
