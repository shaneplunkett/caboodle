{
  config,
  lib,
  nodes,
  pkgs,
  ...
}:
let
  endpoint = "http://${nodes.cache.config.homelab.lanAddress}:8080/";
in
{
  homelab.secrets = [ "attic-push-token" ];
  homelab.monitoring.units = [ "attic-watch-store.service" ];

  systemd.services.attic-watch-store = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment.HOME = "/run/attic-watch-store";
    serviceConfig = {
      DynamicUser = true;
      RuntimeDirectory = "attic-watch-store";
      LoadCredential = "token:${config.age.secrets.attic-push-token.path}";
      Restart = "on-failure";
      RestartSec = 10;
    };
    script = ''
      mkdir -p "$HOME/.config/attic"
      printf 'default-server = "home"\n[servers.home]\nendpoint = "%s"\ntoken = "%s"\n' \
        ${endpoint} "$(< "$CREDENTIALS_DIRECTORY/token")" > "$HOME/.config/attic/config.toml"
      exec ${lib.getExe' pkgs.attic-client "attic"} watch-store home:shane
    '';
  };
}
