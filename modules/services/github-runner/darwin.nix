{
  config,
  lib,
  pkgs,
  ...
}:
let
  name = "mini";
  url = "https://github.com/shaneplunkett/caboodle";
  user = "_github-runner";
  secrets = config.age.secrets;
  cache = import ../harmonia/cache.nix;
  state = "/var/lib/github-runners/${name}";
  logs = "/var/log/github-runners";
  credentials = "/run/github-app";
  tokenFile = "/run/github-runner-registration/token";
  inputsTokenFile = "/run/nix-inputs-token/access-tokens.conf";

  registration = pkgs.writeShellApplication {
    name = "github-runner-registration";
    runtimeInputs = [
      (pkgs.callPackage ./registration-token.nix { })
      pkgs.coreutils
    ];
    text = builtins.readFile ./darwin-registration.sh;
  };

  inputsToken = pkgs.writeShellApplication {
    name = "nix-inputs-token";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./darwin-inputs-token.sh;
  };
in
{
  imports = [ ../harmonia/pusher.nix ];

  homelab.secrets = [
    "github-app-client-id"
    "github-app-private-key"
    "github-inputs-token"
    "mini-cache-ssh-key"
  ];

  age.secrets = {
    github-app-client-id.path = "${credentials}/client-id";
    github-app-private-key.path = "${credentials}/private-key";
    mini-cache-ssh-key.owner = user;
  };

  nix.extraOptions = "!include ${inputsTokenFile}";

  programs.ssh.extraConfig = ''
    Match localuser ${user} host ${cache.name}
      IdentityFile ${secrets.mini-cache-ssh-key.path}
      IdentitiesOnly yes
  '';

  services.github-runners.${name} = {
    enable = true;
    inherit url tokenFile;
    replace = true;
    extraLabels = [ "darwin" ];
    extraPackages = [
      pkgs.flock
      pkgs.openssh
    ];
    serviceOverrides = {
      KeepAlive = lib.mkForce true;
      ProcessType = lib.mkForce "Background";
    };
  };

  launchd.daemons = {
    github-runner-registration = {
      command = "${lib.getExe registration} ${url} ${state} ${tokenFile} ${user}";
      environment.CREDENTIALS_DIRECTORY = credentials;
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 300;
        StandardErrorPath = "${logs}/registration.log";
      };
    };

    nix-inputs-token = {
      command = "${lib.getExe inputsToken} ${secrets.github-inputs-token.path} ${inputsTokenFile} ${user}";
      serviceConfig = {
        RunAtLoad = true;
        StartInterval = 60;
        StandardErrorPath = "${logs}/inputs-token.log";
      };
    };
  };
}
