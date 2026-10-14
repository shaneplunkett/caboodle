# macOS's own man keeps `man -k` and apropos working, which nixpkgs man-db
# does not there. home-manager makes this the darwin default from
# stateVersion 26.05; Nix-installed man pages still show up either way.
{ lib, pkgs, ... }:
{
  programs.man.package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin null;
}
