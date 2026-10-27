{ config, lib, ... }:
let
  shares = {
    programs = "Programs";
    media = "Media";
    games = "Games";
    appdata = "appdata";
  };
in
{
  fileSystems = lib.mapAttrs' (
    dir: share:
    lib.nameValuePair "home/shane/unraid/${dir}" {
      device = "//${config.homelab.devices.pve.ip}/${share}";
      fsType = "cifs";
      options = [
        "guest"
        "uid=1000"
        "gid=100"
        "vers=3.0"
        "x-systemd.automount"
        "x-systemd.idle-timeout=600"
        "nofail"
      ];
    }
  ) shares;
}
