{ config, ... }:
let
  gib = 1024 * 1024 * 1024;
  slack = 5 * gib;
in
{
  imports = [
    ../modules/services/forgejo-runner
    ../modules/services/attic/watch-store.nix
    ../modules/services/harmonia
    ../modules/services/renovate
  ];

  homelab.monitoring.thresholds.disk =
    1 - (config.nix.settings.min-free - slack) / (config.homelab.guest.disk * gib * 1.0);
}
