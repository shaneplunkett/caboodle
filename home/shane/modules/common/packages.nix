{ pkgs, ... }:
{
  home.packages = with pkgs; [
    jq
    fd
    lazygit
    obsidian
    go
    lazydocker
    terraform
    tflint
    tftui
    terraform-docs
    ripgrep
    fzf
    pre-commit
    nix-output-monitor
    nvd
    statix
    deadnix
    manix
    nurl
    nix-init
    nix-update
    gam
  ];
}
