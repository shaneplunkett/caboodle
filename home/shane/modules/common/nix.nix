{ config, ... }:
{
  xdg.configFile."nix/nix.conf".text = ''
    !include ${config.xdg.configHome}/nix/access-tokens.conf
  '';
}
