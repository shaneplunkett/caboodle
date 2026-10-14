{ pkgs, ... }:
let
  taildropAutoReceive = pkgs.writeShellApplication {
    name = "taildrop-auto-receive";
    runtimeInputs = [ pkgs.tailscale ];
    text = ''
      set -euo pipefail

      target="$HOME/Downloads/Taildrop"
      mkdir -p "$target"

      exec tailscale file get --loop --verbose --conflict=rename "$target"
    '';
  };
in
{
  home.packages = [ taildropAutoReceive ];

  systemd.user.services.taildrop-auto-receive = {
    Unit = {
      Description = "Automatically receive Taildrop files";
      After = [ "network-online.target" ];
    };

    Service = {
      Type = "simple";
      ExecStart = "${taildropAutoReceive}/bin/taildrop-auto-receive";
      Restart = "always";
      RestartSec = "10s";
    };

    Install = {
      WantedBy = [ "default.target" ];
    };
  };
}
