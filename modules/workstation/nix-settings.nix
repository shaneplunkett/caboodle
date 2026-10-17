_: {
  nixpkgs.config.allowUnfree = true;
  nix.optimise.automatic = true;

  nix.settings = {
    substituters = [
      "https://cache.shaneplunkett.com"
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];

    trusted-public-keys = [
      "cache.shaneplunkett.com-1:PCAa3NL0WuE581JmS/0zU4FQiAXUsNoKOw6leo5IIaY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
    ];

    http-connections = 6;
    max-substitution-jobs = 4;
    download-buffer-size = 64 * 1024 * 1024;
  };
  home-manager.backupFileExtension = "backup";
  home-manager.overwriteBackup = true;
}
