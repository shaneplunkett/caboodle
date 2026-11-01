_: {
  nixpkgs.config.allowUnfree = true;
  nix.optimise.automatic = true;

  nix.settings = {
    substituters = [
      "https://nix-community.cachix.org"
      "https://noctalia.cachix.org"
      "https://cache.numtide.com"
    ];

    trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
      "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
      "desktop-1:mO15lgmgmGfHf1mZ/R2/Bm/Y3Vg67MemFrw2knVhKdE="
      "mini-1:rRp69qHh8+E4hlmLyboGe3FEizFAd9CcVQqQ4HzYFDo="
    ];

    http-connections = 6;
    max-substitution-jobs = 4;
    download-buffer-size = 64 * 1024 * 1024;
  };
  home-manager.backupFileExtension = "backup";
  home-manager.overwriteBackup = true;
}
