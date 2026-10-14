# Runs the vex-code backend headless on mini-server, in place of the desktop
# app. It's a login agent rather than a boot daemon because agents need the
# login keychain and rbw; auto-login (hosts/darwin/mini) brings the session
# back after a reboot. Tailscale Serve already forwards the tailnet's :3773 to
# 127.0.0.1:3773, and pairings carry over because the base dir is unchanged.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.home) homeDirectory;
  log = "${homeDirectory}/Library/Logs/vex-code.log";
in
{
  launchd.agents.vex-code = {
    enable = true;
    config = {
      ProgramArguments = [
        (lib.getExe' pkgs.vex-code "t3")
        "serve"
        "--mode"
        "web"
        "--host"
        "127.0.0.1"
        "--port"
        "3773"
        "--base-dir"
        "${homeDirectory}/.t3"
      ];
      WorkingDirectory = homeDirectory;
      EnvironmentVariables.PATH = lib.concatStringsSep ":" [
        "${config.home.profileDirectory}/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"
        "/usr/bin"
        "/bin"
        "/usr/sbin"
        "/sbin"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = log;
      StandardErrorPath = log;
    };
  };
}
