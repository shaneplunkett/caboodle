{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.incus;
  vg = "incus";
  thinPoolFile = "${config.homelab.metricsDir}/incus-thinpool.prom";
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
  };

  config = {
    networking = {
      useNetworkd = true;
      useDHCP = false;
      nftables.enable = true;
    };

    systemd.network = {
      netdevs.br0 = {
        netdevConfig = {
          Kind = "bridge";
          Name = "br0";
          MACAddress = cfg.mac;
        };
        bridgeConfig.VLANFiltering = true;
      };
      networks = {
        uplink = {
          matchConfig.Name = cfg.uplink;
          networkConfig.Bridge = "br0";
          bridgeVLANs = [
            {
              PVID = 1;
              EgressUntagged = 1;
            }
            { VLAN = "2-4094"; }
          ];
        };
        br0 = {
          matchConfig.Name = "br0";
          networkConfig.DHCP = "ipv4";
          linkConfig.RequiredFamilyForOnline = "ipv4";
        };
      };
    };

    services.lvm.boot.thin.enable = true;

    homelab.monitoring.units = [ "incus-thinpool-metrics.service" ];

    systemd.services.incus-thinpool-metrics = {
      path = [
        config.services.lvm.package
        pkgs.jq
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        set -o pipefail
        lvs --reportformat json -o lv_name,vg_name,data_percent,metadata_percent -S segtype=thin-pool ${vg} \
          | jq -er '.report[0].lv | if . == [] then error("no thin pool in ${vg}") else .[] end
            | "homelab_incus_thinpool_data_ratio{vg=\"\(.vg_name)\", lv=\"\(.lv_name)\"} \(.data_percent | tonumber / 100)",
              "homelab_incus_thinpool_metadata_ratio{vg=\"\(.vg_name)\", lv=\"\(.lv_name)\"} \(.metadata_percent | tonumber / 100)"' \
          > ${thinPoolFile}.tmp
        echo "homelab_incus_thinpool_collected_timestamp_seconds $(date +%s)" >> ${thinPoolFile}.tmp
        mv ${thinPoolFile}.tmp ${thinPoolFile}
      '';
    };

    systemd.timers.incus-thinpool-metrics = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = "minutely";
    };

    networking.firewall.allowedTCPPorts = [ 8443 ];

    virtualisation.incus = {
      enable = true;
      preseed = {
        config = {
          "core.https_address" = ":8443";
          "core.metrics_authentication" = "false";
        };
        storage_pools = [
          {
            name = "default";
            driver = "lvm";
            config = {
              source = vg;
              "lvm.vg_name" = vg;
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
