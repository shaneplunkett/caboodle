{ pkgs, ... }:
{
  imports = [ ./account-tools.nix ];

  home.packages = [ pkgs.gam ];
}
