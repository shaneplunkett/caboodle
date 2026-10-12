{
  config,
  lib,
  modulesPath,
  ...
}:
let
  inherit (config.homelab.monitoring) units;
in
{
  imports = [
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  options.homelab = {
    lanAddress = lib.mkOption {
      type = lib.types.str;
      description = "The host's LAN address, for anything that must keep working without Tailscale.";
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
      type = lib.types.attrsOf lib.types.port;
      default = { };
      description = "Ports the gateway forwards from the internet to this host, by rule name. The WAN and local port match.";
    };
  };

  config = {
    nixpkgs.hostPlatform = "x86_64-linux"; # the LXCs' platform

    nixpkgs.config.allowUnfree = true;
    nix.optimise.automatic = true;

    programs.nh.clean = {
      enable = true;
      extraArgs = "--keep 2";
    };

    virtualisation.podman.autoPrune = {
      enable = true;
      flags = [ "--all" ];
    };

    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJY/xBlhx6acLxZgcs6yDgDPvfi4aJmxiYy+sk7CQGhy builder"
    ];

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    services.prometheus = {
      exporters.node = {
        inherit (config.homelab.monitoring) enable;
        openFirewall = true;
        enabledCollectors = lib.mkIf (units != [ ]) [ "systemd" ];
        extraFlags = [
          "--collector.textfile.directory=${config.homelab.metricsDir}"
        ]
        ++ lib.optional (units != [ ]) "--collector.systemd.unit-include=${lib.concatStringsSep "|" units}";
      };
    };

    systemd.tmpfiles.rules = [ "d ${config.homelab.metricsDir} 0755 root root -" ];

    system.stateVersion = "26.11";
  };
}
