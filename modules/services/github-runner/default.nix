{
  config,
  lib,
  nodes,
  pkgs,
  ...
}:
let
  name = "homelab";
  url = "https://github.com/shaneplunkett/caboodle";
  user = "github-runner";
  secrets = config.age.secrets;
  state = "/var/lib/github-runner/${name}";
  work = "/var/lib/github-runner-work";
  tokenDir = "github-runner-registration";
  tokenFile = "/run/${tokenDir}/token";
  inputsTokenDir = "nix-inputs-token";
  inputsTokenFile = "/run/${inputsTokenDir}/access-tokens.conf";
  hostKeys = import ../../agenix/host-keys.nix;
  cache = import ../harmonia/cache.nix;
  deployed = lib.filterAttrs (_: node: node.config.homelab.deployedByRunner) nodes;
  gib = n: n * 1024 * 1024 * 1024;

  terraformSecrets = [
    "terraform-cloud-token"
    "terraform-hcloud-token"
    "terraform-cloudflare-token"
    "terraform-access-emails"
    "terraform-unifi-token"
    "terraform-incus-key"
  ];

  slice = "runner";
  fence = {
    Slice = "${slice}.slice";
    OOMPolicy = "continue";
  };

  registration = pkgs.writeShellApplication {
    name = "github-runner-registration";
    runtimeInputs = [
      (pkgs.callPackage ./registration-token.nix { })
      pkgs.coreutils
    ];
    text = builtins.readFile ./nixos-registration.sh;
  };
in
{
  imports = [
    ../../workstation/upstream-caches.nix
    ../harmonia/pusher.nix
  ];

  homelab.secrets = [
    "github-app-client-id"
    "github-app-private-key"
    "github-inputs-token"
    "runner-ssh-key"
  ]
  ++ terraformSecrets;

  age.secrets = lib.genAttrs ([ "runner-ssh-key" ] ++ terraformSecrets) (_: {
    owner = user;
  });

  users.users.${user} = {
    group = user;
    isSystemUser = true;
    home = work;
  };
  users.groups.${user} = { };

  systemd.tmpfiles.rules = [ "d ${work} 0700 ${user} ${user} -" ];

  nix = {
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass = "idle";
    settings = {
      min-free = gib 40;
      max-free = gib 80;
      max-jobs = 2;
      cores = 4;
    };
    extraOptions = "!include ${inputsTokenFile}";
  };

  networking.hosts = lib.mapAttrs' (
    name: node: lib.nameValuePair node.config.homelab.lanAddress [ name ]
  ) deployed;

  programs.ssh = {
    extraConfig = ''
      Match localuser ${user} host ${
        lib.concatStringsSep "," (builtins.attrNames deployed ++ [ cache.name ])
      }
        IdentityFile ${secrets.runner-ssh-key.path}
      Match all
    '';
    knownHosts = lib.mapAttrs (name: node: {
      hostNames = [
        name
        node.config.homelab.lanAddress
      ];
      publicKey = hostKeys.${name};
    }) deployed;
  };

  systemd.slices.${slice}.sliceConfig = {
    MemoryMax = "28G";
    CPUWeight = "idle";
    IOWeight = 1;
  };

  systemd.services.nix-daemon.serviceConfig = fence;

  services.github-runners.${name} = {
    enable = true;
    inherit
      url
      tokenFile
      user
      ;
    tokenType = "registration";
    replace = true;
    extraLabels = [ name ];
    extraPackages = [
      pkgs.colmena
      pkgs.dnsutils
      pkgs.openssh
      pkgs.terraform
      pkgs.util-linux
    ];
    workDir = work;
    serviceOverrides = fence // {
      Restart = lib.mkForce "on-failure";
      RestartSec = "30s";
    };
  };

  systemd.services.github-runner-registration = {
    description = "Ask GitHub for a registration token if the runner needs one";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    before = [ "github-runner-${name}.service" ];
    requiredBy = [ "github-runner-${name}.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe registration} ${url} ${state} ${tokenFile}";
      RuntimeDirectory = tokenDir;
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = true;
      LoadCredential = [
        "client-id:${secrets.github-app-client-id.path}"
        "private-key:${secrets.github-app-private-key.path}"
      ];
    };
  };

  systemd.services.nix-inputs-token = {
    description = "Write the inputs token where the job's Nix reads it";
    before = [ "github-runner-${name}.service" ];
    requiredBy = [ "github-runner-${name}.service" ];
    restartTriggers = [ (builtins.hashFile "sha256" secrets.github-inputs-token.file) ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = inputsTokenDir;
    };
    script = ''
      token=$(<${secrets.github-inputs-token.path})
      printf 'access-tokens = github.com=%s\n' "$token" |
        install -m 0640 -g ${user} /dev/stdin ${inputsTokenFile}
    '';
  };
}
