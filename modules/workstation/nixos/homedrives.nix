_: {
  fileSystems = {
    "home/shane/unraid/programs" = {
      device = "//192.168.1.132/Programs";
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
    };
    "home/shane/unraid/media" = {
      device = "//192.168.1.132/media";
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
    };
    "home/shane/unraid/appdata" = {
      device = "//192.168.1.132/appdata";
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
    };
  };
}
