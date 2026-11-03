{
  config,
  lib,
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
  gib = n: n * 1024 * 1024 * 1024;

  fence = {
    MemoryMax = "28G";
    OOMPolicy = "continue";
  };

  registrationToken = pkgs.writeShellApplication {
    name = "github-runner-registration-token";
    runtimeInputs = [
      (pkgs.callPackage ../../../pkgs/github-app-token { })
      pkgs.curl
      pkgs.jq
    ];
    text = builtins.readFile ./registration-token.sh;
  };
in
{
  homelab.secrets = [
    "github-app-client-id"
    "github-app-private-key"
  ];

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
    };
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
    extraPackages = [ pkgs.util-linux ];
    workDir = work;
    serviceOverrides = fence // {
      CPUWeight = "idle";
      IOWeight = 1;
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
      ExecStart = "${lib.getExe registrationToken} ${url} ${state} ${tokenFile}";
      RuntimeDirectory = tokenDir;
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = true;
      LoadCredential = [
        "client-id:${secrets.github-app-client-id.path}"
        "private-key:${secrets.github-app-private-key.path}"
      ];
    };
  };
}
