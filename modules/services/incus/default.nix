{
  config,
  lib,
  pkgs,
  ...
}:
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

    services.lvm.boot.thin.enable = true;

    networking.firewall.allowedTCPPorts = [ 8443 ];

    virtualisation.incus = {
      enable = true;
      preseed = {
        config."core.https_address" = ":8443";
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
              tun = {
                type = "unix-char";
                source = "/dev/net/tun";
                path = "/dev/net/tun";
              };
            };
          }
        ];
      };
    };

    systemd.services.incus-trust-terraform = {
      wantedBy = [ "incus.service" ];
      after = [ "incus-preseed.service" ];
      bindsTo = [ "incus.service" ];
      path = [
        config.virtualisation.incus.package
        pkgs.openssl
      ];
      script = ''
        fingerprint=$(openssl x509 -in ${./terraform.crt} -noout -fingerprint -sha256 | cut -d= -f2 | tr -d : | tr A-F a-f)
        incus config trust show "$fingerprint" > /dev/null 2>&1 \
          || incus config trust add-certificate ${./terraform.crt} --name terraform
      '';
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
