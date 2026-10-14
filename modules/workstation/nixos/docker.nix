{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    autoPrune.dates = "weekly";
  };

  environment.systemPackages = [ pkgs.docker-compose ];
}
