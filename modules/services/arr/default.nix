{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.arr;
  sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";

  dump =
    db:
    let
      dumps = "${dirOf db}/dumps";
    in
    ''
      if [ -e ${db} ]; then
        install -d -m 0700 ${dumps}
        ${sqlite3} ${db} ".backup '${dumps}/${baseNameOf db}'"
        for f in ${db}-wal ${db}-shm; do
          if [ -e "$f" ]; then chown --reference=${db} "$f"; fi
        done
      fi
    '';
in
{
  imports = [
    ./calibre-web-automated.nix
    ./deluge.nix
    ./maintainerr.nix
    ./prowlarr.nix
    ./radarr.nix
    ./sabnzbd.nix
    ./seerr.nix
    ./shelfarr.nix
    ./sonarr.nix
    ./tautulli.nix
  ];

  options.homelab.arr.databases = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
    description = "SQLite databases under homelab.backup.paths, backed up as a consistent dump in a dumps/ folder next to them instead of as live files.";
  };

  config = {
    homelab.backup = {
      exclude = map (db: "${db}*") cfg.databases;
      prepare = lib.concatMapStrings dump cfg.databases;
    };

    systemd.services = lib.mapAttrs' (
      name: _: lib.nameValuePair "podman-${name}" { environment.XDG_RUNTIME_DIR = "/run"; }
    ) config.virtualisation.oci-containers.containers;
  };
}
