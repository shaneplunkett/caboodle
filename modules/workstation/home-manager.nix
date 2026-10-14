{ inputs, ... }:
{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = {
      inherit inputs;
      palette = import ../../home/palette.nix;
      typography = import ../../home/typography.nix;
    };
    sharedModules = [
      inputs.nixvim.homeModules.nixvim
      inputs.catppuccin.homeModules.catppuccin
      (
        { lib, ... }:
        {
          catppuccin.autoEnable = lib.mkDefault false;
        }
      )
      inputs.nix-index-database.homeModules.nix-index
      ../../home/shane/modules/agent-clis
      inputs.vex-brain.homeManagerModules.vex-cli
      { programs.vex-cli.enable = true; }
    ];
  };
}
