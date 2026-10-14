_: {
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    withNodeJs = true;
    viAlias = true;
    vimAlias = true;

    imports = [
      ./colorschemes.nix
      ./globals.nix
      ./keymaps.nix
      ./options.nix
      ./plugins
    ];
  };
}
