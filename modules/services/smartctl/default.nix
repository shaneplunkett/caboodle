{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.smartmontools ];

  services.prometheus.exporters.smartctl = {
    enable = true;
    openFirewall = true;
    maxInterval = "5m";
  };
}
