{ lib, ... }:
let
  nopasswd = command: {
    inherit command;
    options = [ "NOPASSWD" ];
  };

  switchActions = [
    "boot"
    "test"
    "switch"
  ];

  switchCommand = action: "/nix/store/*-nixos-system-*/bin/switch-to-configuration ${action}";

  envPrefixes = [
    "/run/current-system/sw/bin/env"
    "/nix/store/*-coreutils-*/bin/env"
  ];
in
{

  users.users.shane = {
    isNormalUser = true;
    description = "Shane Plunkett";
    extraGroups = [
      "docker"
      "networkmanager"
      "dialout"
      "wheel"
    ];
  };

  security.sudo.extraRules = [
    {
      users = [ "shane" ];
      commands = map nopasswd (
        (map switchCommand switchActions)
        ++ (lib.concatMap (
          env:
          (map (action: "${env} * ${switchCommand action}") switchActions)
          ++ [
            "${env} * nix build --no-link --profile /nix/var/nix/profiles/system /nix/store/*-nixos-system-*"
            "${env} * ln -sfn /nix/var/nix/profiles/system-*-link /nix/var/nix/profiles/system"
          ]
        ) envPrefixes)
      );
    }
  ];
}
