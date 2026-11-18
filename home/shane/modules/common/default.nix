{ inputs, ... }:
{
  imports = [
    inputs.nix-config-private.homeManagerModules.default
    ./ai
    ./btop.nix
    ./claude-work.nix
    ./git.nix
    ./lazygit.nix
    ./nh.nix
    ./nix.nix
    ./nix-index.nix
    ./nixvim
    ./packages.nix
    ./personal.nix
    ./rbw.nix
    ./ssh.nix
    ./terraform.nix
    ./terminal
    ./theme
    ./vex-code.nix
  ];
}
