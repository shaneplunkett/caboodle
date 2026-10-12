{ config, ... }:
let
  host = "mini-server";
  address = config.homelab.devices.mini.ip;
in
{
  nix = {
    distributedBuilds = true;
    settings.builders-use-substitutes = true;
    buildMachines = [
      {
        hostName = host;
        protocol = "ssh-ng";
        sshUser = "shane";
        sshKey = config.age.secrets.builder-ssh-key.path;
        systems = [ "aarch64-darwin" ];
        maxJobs = 3;
        supportedFeatures = [ "big-parallel" ];
      }
    ];
  };

  programs.ssh = {
    knownHosts.${host} = {
      hostNames = [
        host
        address
      ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0d9nOtZXKbdHdTpyqr3sCU3PY3JOYb+quchdDBwZpB";
    };
    extraConfig = ''
      Host ${host}
        HostName ${address}
    '';
  };
}
