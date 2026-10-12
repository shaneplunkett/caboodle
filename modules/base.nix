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
