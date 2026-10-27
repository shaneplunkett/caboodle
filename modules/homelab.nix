{ config, lib, ... }:
{
  options.homelab = {
    lanAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "The host's LAN address, for anything that must keep working without Tailscale. A host that's always on the LAN has one; a laptop doesn't.";
    };

    guest = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            host = lib.mkOption {
              type = lib.types.str;
              description = "The Incus remote the container runs on.";
            };
            cores = lib.mkOption {
              type = lib.types.ints.positive;
              default = 2;
            };
            memory = lib.mkOption {
              type = lib.types.ints.positive;
              default = 2048;
              description = "Memory in MiB.";
            };
            disk = lib.mkOption {
              type = lib.types.ints.positive;
              default = 8;
              description = "Root disk in GiB.";
            };
            mac = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "MAC address for eth0, generated if unset. UniFi reserves the host's LAN address for it.";
            };
            running = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the container should be running.";
            };
          };
        }
      );
      default = null;
      description = "The Incus container the host runs in. Terraform creates it from the base image and reserves its LAN address in UniFi.";
    };

    sshUser = lib.mkOption {
      type = lib.types.str;
      default = "root";
      description = "Who Shane logs in as over SSH.";
    };

    metricsDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prometheus-node-exporter-text";
      readOnly = true;
      description = "Where jobs drop .prom files for node exporter to publish.";
    };

    monitoring = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the host runs node exporter and Prometheus scrapes it.";
      };

      units = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "systemd units whose state node exporter publishes, for alerts on them.";
      };

      thresholds = {
        memoryAvailable = lib.mkOption {
          type = lib.types.float;
          default = 0.10;
          description = "Alert when the free share of memory drops below this.";
        };

        cpu = lib.mkOption {
          type = lib.types.float;
          default = 0.9;
          description = "Alert when sustained CPU use goes above this share.";
        };

        disk = lib.mkOption {
          type = lib.types.float;
          default = 0.85;
          description = "Alert when the root disk fills beyond this share.";
        };
      };
    };

    routes = lib.mkOption {
      type = lib.types.attrsOf lib.types.port;
      default = { };
      description = "Subdomains the ingress host proxies to this host, mapped to the local port.";
    };

    oidcClients = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "The client's name in Pocket ID.";
            };
            callbackURLs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Where Pocket ID may send the user back to after sign-in.";
            };
            launchURL = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The app's address, linked from Pocket ID's dashboard.";
            };
            pkce = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the client uses PKCE. Turn it off for apps that don't support it.";
            };
            groups = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "The user groups allowed to sign in. Missing groups are created.";
            };
            secret = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The agenix secret holding the client secret, which the auth host must be able to decrypt. It's only set when the client is created.";
            };
          };
        }
      );
      default = { };
      description = "Pocket ID clients this host's apps sign in with, keyed by client ID. The auth host creates and updates them.";
    };

    portForwards = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.coercedTo lib.types.port (port: { inherit port; }) (
          lib.types.submodule {
            options = {
              port = lib.mkOption { type = lib.types.port; };
              protocol = lib.mkOption {
                type = lib.types.enum [
                  "tcp"
                  "udp"
                  "tcp_udp"
                ];
                default = "tcp_udp";
              };
            };
          }
        )
      );
      default = { };
      description = "Ports the gateway forwards from the internet to this host, by rule name, as a port or a port and protocol. The WAN and local port match.";
    };
  };

  config.assertions = [
    {
      assertion =
        config.homelab.lanAddress != null
        || (
          !config.homelab.monitoring.enable
          && config.homelab.routes == { }
          && config.homelab.portForwards == { }
        );
      message = "homelab.monitoring, homelab.routes and homelab.portForwards all reach the host by its LAN address, so a host using any of them needs homelab.lanAddress.";
    }
  ];
}
