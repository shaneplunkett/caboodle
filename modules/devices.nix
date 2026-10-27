{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  device =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          description = "The device's name in UniFi.";
        };

        ip = mkOption {
          type = types.str;
          description = "The address UniFi reserves for the device.";
        };

        mac = mkOption {
          type = types.strMatching "([0-9a-f]{2}:){5}[0-9a-f]{2}";
          description = "The device's MAC address, in lowercase.";
        };

        proxmox = mkOption {
          type = types.bool;
          default = false;
          description = "Whether the device is a Proxmox node.";
        };
      };
    };
in
{
  options.homelab = {
    gateway = mkOption {
      type = types.str;
      description = "The UniFi gateway's LAN address.";
    };

    devices = mkOption {
      type = types.attrsOf (types.submodule device);
      apply =
        devices:
        assert lib.assertMsg (lib.allUnique (
          map (device: device.ip) (lib.attrValues devices)
        )) "Two devices in homelab.devices share an IP.";
        devices;
      description = "Every device on the network that isn't a NixOS host, reserved in UniFi by Terraform.";
    };

    proxmoxNodes = mkOption {
      type = types.attrsOf types.str;
      readOnly = true;
      default = lib.mapAttrs (_: device: device.ip) (
        lib.filterAttrs (_: device: device.proxmox) config.homelab.devices
      );
      description = "Each Proxmox node's address, keyed by its node name.";
    };
  };

  config.homelab = {
    gateway = "192.168.1.1";

    devices = {
      pve = {
        name = "Beast";
        ip = "192.168.1.169";
        mac = "e8:9c:25:7a:2d:c4";
      };
      cube = {
        name = "Cube";
        ip = "192.168.1.238";
        mac = "e0:d5:5e:84:3e:48";
        proxmox = true;
      };
      mini = {
        name = "Mini";
        ip = "192.168.1.252";
        mac = "bc:74:ea:e8:00:97";
      };
      appleTv = {
        name = "Apple TV";
        ip = "192.168.1.75";
        mac = "f0:b3:ec:0a:fc:98";
      };
      nixDesktop = {
        name = "Nix-Desktop";
        ip = "192.168.1.100";
        mac = "a8:a1:59:f0:68:ef";
      };
      bambuX1c = {
        name = "Bambu X1C";
        ip = "192.168.1.106";
        mac = "50:41:1c:89:2f:40";
      };
      raspberryPi4 = {
        name = "Raspberry Pi 4";
        ip = "192.168.1.162";
        mac = "e4:5f:01:95:0d:b9";
      };
      jetKvm = {
        name = "JetKVM";
        ip = "192.168.1.168";
        mac = "30:52:53:07:0d:1c";
      };
      raspberryPi2 = {
        name = "Raspberry Pi 2";
        ip = "192.168.1.194";
        mac = "b8:27:eb:b1:b8:7e";
      };
      merossPlug524f = {
        name = "Meross Plug 524f";
        ip = "192.168.20.15";
        mac = "48:e1:e9:af:52:4f";
      };
      sensibo = {
        name = "Sensibo";
        ip = "192.168.20.22";
        mac = "94:b5:55:ae:d5:e8";
      };
      lifxSwitch6c55c7 = {
        name = "LIFX Switch 6C55C7";
        ip = "192.168.20.23";
        mac = "d0:73:d5:6c:55:c8";
      };
      gaggiuino = {
        name = "Gaggiuino";
        ip = "192.168.20.29";
        mac = "a0:85:e3:f3:45:7c";
      };
      merossPlugDfb5 = {
        name = "Meross Plug dfb5";
        ip = "192.168.20.47";
        mac = "48:e1:e9:a6:df:b5";
      };
      hueBridge = {
        name = "Hue Bridge";
        ip = "192.168.20.60";
        mac = "ec:b5:fa:8f:a1:b6";
      };
      wiz3f1c36 = {
        name = "WiZ 3f1c36";
        ip = "192.168.20.106";
        mac = "98:77:d5:3f:1c:36";
      };
      merossStripD56c = {
        name = "Meross Strip d56c";
        ip = "192.168.20.108";
        mac = "48:e1:e9:93:d5:6c";
      };
      balconyShelly = {
        name = "Balcony Shelly";
        ip = "192.168.20.115";
        mac = "98:cd:ac:1e:a8:43";
      };
      dyson = {
        name = "Dyson";
        ip = "192.168.20.123";
        mac = "44:6f:f8:5e:28:7d";
      };
      merossSmartSwitch = {
        name = "Meross Smart Switch";
        ip = "192.168.20.128";
        mac = "c4:e7:ae:1e:e4:83";
      };
      boseEthernet = {
        name = "Bose Soundbar (Ethernet)";
        ip = "192.168.20.134";
        mac = "c8:7b:23:b1:bc:78";
      };
      bose = {
        name = "Bose Soundbar";
        ip = "192.168.20.140";
        mac = "c8:7b:23:b1:bc:7e";
      };
      lifxSwitch6c378f = {
        name = "LIFX Switch 6C378F";
        ip = "192.168.20.161";
        mac = "d0:73:d5:6c:37:90";
      };
      lgTvEthernet = {
        name = "LG TV (Ethernet)";
        ip = "192.168.20.70";
        mac = "b0:37:95:1b:4c:bc";
      };
      lgTv = {
        name = "LG TV";
        ip = "192.168.20.71";
        mac = "dc:03:98:56:11:9a";
      };
      slzb = {
        name = "SLZB";
        ip = "192.168.20.192";
        mac = "1c:69:20:92:8f:9f";
      };
      merossStripDe3a = {
        name = "Meross Strip de3a";
        ip = "192.168.20.193";
        mac = "48:e1:e9:a4:de:3a";
      };
      merossStripDc3c = {
        name = "Meross Strip dc3c";
        ip = "192.168.20.220";
        mac = "48:e1:e9:a4:dc:3c";
      };
      merossPlug566f = {
        name = "Meross Plug 566f";
        ip = "192.168.20.224";
        mac = "48:e1:e9:af:56:6f";
      };
    };
  };
}
