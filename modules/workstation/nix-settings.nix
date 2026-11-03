_: {
  imports = [ ./upstream-caches.nix ];

  nixpkgs.config.allowUnfree = true;
  nix.optimise.automatic = true;

  nix.settings = {
    http-connections = 6;
    max-substitution-jobs = 4;
    download-buffer-size = 64 * 1024 * 1024;
  };
  home-manager.backupFileExtension = "backup";
  home-manager.overwriteBackup = true;
}
