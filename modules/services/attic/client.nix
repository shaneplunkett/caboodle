{ config, pkgs, ... }:
{
  homelab.secrets = [ "attic-netrc" ];

  age.secrets.attic-netrc = {
    group = if pkgs.stdenv.hostPlatform.isDarwin then "admin" else "wheel";
    mode = "0440";
  };

  nix.settings = {
    substituters = [ "https://cache.shaneplunkett.com/shane" ];
    trusted-public-keys = [ "shane:T+Jq4M4cvkVyJwM7k5/zbOevaD1vfXzoqVX9a2hXCZI=" ];
    netrc-file = config.age.secrets.attic-netrc.path;
  };
}
