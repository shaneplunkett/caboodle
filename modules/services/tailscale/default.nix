{ config, lib, ... }:
let
  cfg = config.homelab.tailscale;
in
{
  imports = [ ./options.nix ];

  config = lib.mkIf cfg.enable {
    homelab.secrets = [ "tailscale-oauth" ];

    services.tailscale = {
      enable = true;
      authKeyFile = config.age.secrets.tailscale-oauth.path;
      authKeyParameters = {
        ephemeral = false;
        preauthorized = true;
      };
      extraUpFlags = [ "--advertise-tags=tag:homelab" ];
      extraSetFlags = [
        "--accept-routes=false"
        "--accept-dns=false"
      ]
      ++ lib.optional cfg.subnetRouter "--advertise-routes=192.168.1.0/24";
      useRoutingFeatures = if cfg.subnetRouter then "server" else "none";
    };

    systemd.services.tailscaled-autoconnect.serviceConfig = {
      Restart = "on-failure";
      RestartSec = "10s";
    };

    homelab.monitoring.units = [ "tailscaled.service" ];
  };
}
