{ config, lib, ... }:
let
  inherit (config.homelab.monitoring) units;
in
{
  nixpkgs.config.allowUnfree = true;
  nix.optimise.automatic = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  programs.nh.clean = {
    enable = true;
    extraArgs = "--keep 2";
  };

  services.prometheus = {
    exporters.node = {
      inherit (config.homelab.monitoring) enable;
      openFirewall = true;
      enabledCollectors = lib.mkIf (units != [ ]) [ "systemd" ];
      extraFlags = [
        "--collector.textfile.directory=${config.homelab.metricsDir}"
      ]
      ++ lib.optional (units != [ ]) "--collector.systemd.unit-include=${lib.concatStringsSep "|" units}";
    };
  };

  systemd.tmpfiles.rules = [ "d ${config.homelab.metricsDir} 0755 root root -" ];
}
