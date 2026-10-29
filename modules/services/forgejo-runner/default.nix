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
  onLan = lib.attrNames (lib.filterAttrs (_: node: node.config.homelab.lanAddress != null) nodes);
  credentials = {
    ssh-key = "builder-ssh-key";
  }
  // lib.genAttrs [
    "forge-bot-token"
    "terraform-cloud-token"
    "terraform-hcloud-token"
    "terraform-cloudflare-token"
    "terraform-access-emails"
    "terraform-forgejo-token"
    "terraform-unifi-token"
    "terraform-incus-key"
  ] lib.id;
  secrets = [ "forgejo-runner-secret" ] ++ lib.attrValues credentials;
in
{
  imports = [ ./darwin-builder.nix ];

  homelab = {
    inherit secrets;
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
      pkgs.util-linux
    ];
  };

  systemd.tmpfiles.settings = {
    forgejo-runner-tmp."/var/lib/private/forgejo-runner/builder/tmp".e.age = "1d";
    forgejo-runner-evals."/var/lib/private/forgejo-runner/builder/evals".e.age = "30d";
  };

  systemd.services.${unit} = {
    environment.TMPDIR = "/var/lib/forgejo-runner/builder/tmp";
    reloadIfChanged = true;
    restartTriggers = map (name: builtins.hashFile "sha256" config.age.secrets.${name}.file) secrets;
    serviceConfig = {
      ExecReload = "+${config.systemd.package}/bin/systemd-run --on-active=5s ${config.systemd.package}/bin/systemctl --no-block restart ${unit}.service";
      TimeoutStopSec = "65min";
      KillMode = "mixed";
      MemoryMax = "32G";
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
      ManagedOOMMemoryPressureDurationSec = "20s";
      OOMPolicy = "continue";
      StateDirectory = lib.mkForce [
        "forgejo-runner/builder"
        "forgejo-runner/builder/tmp"
      ];
      LoadCredential = lib.mapAttrsToList (
        credential: secret: "${credential}:${config.age.secrets.${secret}.path}"
      ) credentials;
    };
  };

  programs.ssh = {
    knownHosts = lib.mapAttrs (name: publicKey: {
      hostNames = [
        name
        (lanAddress name)
      ];
      inherit publicKey;
    }) (lib.filterAttrs (name: _: lib.elem name onLan) (import ../../agenix/host-keys.nix));
    extraConfig = lib.concatMapStrings (name: ''
      Host ${name} ${lanAddress name}
        HostName ${lanAddress name}
        IdentityFile /run/credentials/${unit}.service/ssh-key
    '') onLan;
  };

  programs.nix-ld.enable = true;

  nix.settings = {
    min-free = 20 * 1024 * 1024 * 1024;
    max-free = 40 * 1024 * 1024 * 1024;
    extra-substituters = [
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];
  };
}
