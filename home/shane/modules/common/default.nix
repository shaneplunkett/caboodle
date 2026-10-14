{ inputs, ... }:
{
  imports = [
    ./account-tools.nix
    inputs.nix-config-private.homeManagerModules.default
    ./ai
    ./btop.nix
    ./git.nix
    ./lazygit.nix
    ./nh.nix
    ./nix-index.nix
    ./nixvim
    ./packages.nix
    ./rbw.nix
    ./ssh.nix
    ./terraform.nix
    ./terminal
    ./theme
    ./vex-code.nix
  ];
}
