{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  unit = "forgejo-runner-builder";
  lanAddress = name: nodes.${name}.config.homelab.lanAddress;
in
{
  imports = [ ./darwin-builder.nix ];

  homelab = {
    secrets = [
      "forgejo-runner-secret"
      "builder-ssh-key"
      "forge-bot-token"
      "terraform-cloud-token"
      "terraform-pve-token"
      "terraform-hcloud-token"
      "terraform-cloudflare-token"
      "terraform-access-emails"
      "terraform-forgejo-token"
    ];
    monitoring.units = [ "${unit}.service" ];
  };

  services.forgejo-runner.instances.builder = {
    enable = true;
    settings = {
      runner = {
        capacity = 4;
        labels = [ "nix:host" ];
        shutdown_timeout = "1h";
      };
      server.connections.forge = {
        url = nodes.forge.config.services.forgejo.settings.server.ROOT_URL;
        uuid = "30653033-3932-6431-3831-386539343732";
      };
    };
    secrets.server.connections.forge.token_url = config.age.secrets.forgejo-runner-secret.path;
    hostPackages = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.gnused
      pkgs.jq
      pkgs.nodejs
      config.programs.ssh.package
      config.nix.package
      pkgs.colmena
      pkgs.terraform
    ];
  };

  systemd.tmpfiles.settings.forgejo-runner-tmp."/var/lib/private/forgejo-runner/builder/tmp".e.age =
    "1d";

  systemd.services.${unit} = {
    environment.TMPDIR = "/var/lib/forgejo-runner/builder/tmp";
    reloadIfChanged = true;
    serviceConfig = {
      ExecReload = "${config.systemd.package}/bin/systemctl --no-block restart ${unit}.service";
      TimeoutStopSec = "65min";
      StateDirectory = lib.mkForce [
        "forgejo-runner/builder"
        "forgejo-runner/builder/tmp"
      ];
      LoadCredential = [
        "ssh-key:${config.age.secrets.builder-ssh-key.path}"
        "forge-bot-token:${config.age.secrets.forge-bot-token.path}"
        "terraform-cloud-token:${config.age.secrets.terraform-cloud-token.path}"
        "terraform-pve-token:${config.age.secrets.terraform-pve-token.path}"
        "terraform-hcloud-token:${config.age.secrets.terraform-hcloud-token.path}"
        "terraform-cloudflare-token:${config.age.secrets.terraform-cloudflare-token.path}"
        "terraform-access-emails:${config.age.secrets.terraform-access-emails.path}"
        "terraform-forgejo-token:${config.age.secrets.terraform-forgejo-token.path}"
      ];
    };
  };

  programs.ssh = {
    knownHosts = lib.mapAttrs (name: publicKey: {
      hostNames = [
        name
        (lanAddress name)
      ];
      inherit publicKey;
    }) (import ../../agenix/host-keys.nix);
    extraConfig = lib.concatMapStrings (name: ''
      Host ${name}
        HostName ${lanAddress name}
        IdentityFile /run/credentials/${unit}.service/ssh-key
    '') (lib.attrNames nodes)
    + ''
      Host 192.168.1.169 192.168.1.238
        User shane
        IdentityFile /run/credentials/${unit}.service/ssh-key
    '';
  };

  programs.nix-ld.enable = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings = {
    min-free = 20 * 1024 * 1024 * 1024;
    max-free = 40 * 1024 * 1024 * 1024;
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
