{
  config,
  inputs,
  pkgs,
  ...
}:
let
  hostKeys = import ../../modules/agenix/host-keys.nix;
  desktop = config.homelab.devices.nixDesktop.ip;
in
{
  imports = [
    inputs.jovian.nixosModules.default
    inputs.disko.nixosModules.disko
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/workstation
    ../../modules/workstation/nixos
  ];

  deployment = {
    tags = [ ];
    allowLocalDeployment = true;
  };

  homelab = {
    monitoring.enable = false;
    tailscale.enable = false;
    emulation.root = "/run/media/shane/bebbbd81-2e56-4cfb-983a-7e04d3608c7d/Emulation";
  };

  networking = {
    hostName = "deck";
    networkmanager.enable = true;
    firewall.trustedInterfaces = [ "tailscale0" ];
  };

  jovian = {
    devices.steamdeck.enable = true;
    steam = {
      enable = true;
      autoStart = true;
      user = "shane";
      desktopSession = "plasma";
    };
  };

  services = {
    desktopManager.plasma6.enable = true;
    tailscale.enable = true;
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="spi", KERNEL=="spi-VLV1776:0[01]", ATTR{power/control}="on"
  '';

  environment.systemPackages = [ pkgs.moonlight-qt ];

  nix.settings.substituters = [ "ssh-ng://nix-ssh@${desktop}" ];
  programs.ssh = {
    knownHosts.desktop-lan = {
      hostNames = [ desktop ];
      publicKey = hostKeys.desktop;
    };
    extraConfig = ''
      Match localuser root host ${desktop}
        IdentityFile /etc/ssh/ssh_host_ed25519_key
        IdentitiesOnly yes
        ConnectTimeout 5
    '';
  };

  security.sudo.wheelNeedsPassword = false;

  users.users.shane.openssh.authorizedKeys.keyFiles = [
    ../../modules/workstation/authorized-keys
  ];

  home-manager.users.shane = import ../../home/shane/homedeck.nix;

  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 10;
      editor = false;
      bootCounting.enable = true;
    };
    efi.canTouchEfiVariables = true;
  };

  system.stateVersion = "26.11";
}
