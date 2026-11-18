{ inputs, ... }:
{
  imports = [
    ../modules/workstation
    ../modules/workstation/darwin
    ../modules/workstation/darwin/laptop
  ];

  disabledModules = [ ../modules/workstation/darwin/laptop/personal.nix ];

  deployment = {
    systemType = "darwin";
    targetUser = "shane";
    tags = [ ];
  };

  homelab = {
    monitoring.enable = false;
    tailscale.enable = false;
  };

  networking = {
    computerName = "Shane's MacBook Air";
    hostName = "Shanes-MacBook-Air";
  };

  home-manager.users.shane =
    { config, lib, ... }:
    let
      vex = "${config.home.profileDirectory}/bin/vex";
    in
    {
      imports = [
        ../home/shane/homemac.nix
        inputs.nix-config-private.homeManagerModules.work
      ];

      disabledModules = [
        ../home/shane/modules/common/personal.nix
        ../home/shane/modules/vesktop.nix
      ];

      launchd.agents = {
        vex-sync-cc.config.ProgramArguments = lib.mkForce [
          vex
          "sync-cc"
          "--projects-dir"
          "${config.home.homeDirectory}/.claude/projects"
        ];
        vex-sync-codex.config.ProgramArguments = lib.mkForce [
          vex
          "sync-codex"
          "--sessions-dir"
          "${config.home.homeDirectory}/.codex/sessions"
        ];
      };
    };

  system.stateVersion = 6;
}
