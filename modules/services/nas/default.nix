{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.nas;

  disks = {
    disk1 = "792d85a0-0f78-4bb0-80e2-443eb3ccdcad";
    disk2 = "6b0ab25a-85d6-43ae-b27e-682af8037088";
    disk3 = "a32ee9f3-744a-4115-aa25-d8bf86bce5bb";
    disk4 = "32fac3a8-80a7-4ed6-9245-ea67dcfbbf91";
    disk5 = "57f17549-f5fd-4abe-8993-f3825e7be419";
    disk7 = "9a20e8a3-5735-489a-969a-77d2c8e9f0c2";
    disk8 = "acf158ee-a98a-4922-beb1-fd55660ee335";
  };
  cache = "52344159-9da8-483a-8130-8db816a2069a";

  shares = {
    Media = 100;
    appdata = 101;
    Programs = 102;
    Games = 103;
  };
  moved = [
    "Media"
    "Programs"
    "Games"
  ];

  diskMounts = map (name: "/mnt/${name}") (builtins.attrNames disks);
  writable = lib.optional cfg.readOnly "ro";

  pool = create: branches: {
    device = lib.concatStringsSep ":" branches;
    fsType = "fuse.mergerfs";
    options = [
      "category.create=${create}"
      "minfreespace=100G"
      "moveonenospc=true"
      "dropcacheonclose=true"
      "never-forget-nodes=true"
      "inodecalc=path-hash"
      "lazy-umount-mountpoint=false"
      "fsname=mergerfs"
      "nofail"
    ]
    ++ map (branch: "x-systemd.requires-mounts-for=${branch}") branches;
  };
in
{
  options.homelab.nas.readOnly = lib.mkEnableOption "mounting the drives read-only, with the mover off";

  config = {
    system.fsPackages = [ pkgs.mergerfs ];

    fileSystems =
      lib.mapAttrs' (
        name: uuid:
        lib.nameValuePair "/mnt/${name}" {
          device = "/dev/disk/by-uuid/${uuid}";
          fsType = "xfs";
          options = [ "nofail" ] ++ writable;
        }
      ) disks
      // {
        "/mnt/cache" = {
          device = "/dev/disk/by-uuid/${cache}";
          fsType = "btrfs";
          options = [
            "nofail"
            "noatime"
          ]
          ++ writable;
        };
        "/mnt/user" = pool "ff" ([ "/mnt/cache" ] ++ diskMounts);
        "/mnt/user0" = pool "mfs" diskMounts;
      };

    users.users.nas = {
      uid = 99;
      group = "users";
      isSystemUser = true;
    };

    services.nfs.server = {
      enable = true;
      statdPort = 4000;
      lockdPort = 4001;
      mountdPort = 4002;
      exports = lib.concatStrings (
        lib.mapAttrsToList (share: fsid: ''
          /mnt/user/${share} *(rw,sec=sys,insecure,all_squash,anonuid=99,anongid=100,async,no_subtree_check,fsid=${toString fsid})
        '') shares
      );
    };

    services.samba = {
      enable = true;
      openFirewall = true;
      settings = {
        global = {
          "server string" = "nas";
          "server min protocol" = "SMB2";
          "disable netbios" = "yes";
          "load printers" = "no";
          "map to guest" = "Bad User";
          "guest account" = "nas";
          "force user" = "nas";
          "force group" = "users";
          "create mask" = "0777";
          "directory mask" = "0777";
          "vfs objects" = "catia fruit streams_xattr";
        };
      }
      // lib.mapAttrs (share: _: {
        path = "/mnt/user/${share}";
        "guest ok" = "yes";
        "read only" = "no";
      }) shares;
    };

    systemd.services = {
      nfs-server.unitConfig.RequiresMountsFor = [ "/mnt/user" ];
      samba-smbd.unitConfig.RequiresMountsFor = [ "/mnt/user" ];

      nas-shares = lib.mkIf (!cfg.readOnly) {
        wantedBy = [
          "nfs-server.service"
          "samba-smbd.service"
        ];
        before = [
          "nfs-server.service"
          "samba-smbd.service"
        ];
        unitConfig.RequiresMountsFor = [ "/mnt/user" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = lib.concatMapStrings (share: ''
          install -d -o nas -g users -m 0777 /mnt/user/${share}
        '') (builtins.attrNames shares);
      };

      nas-mover = lib.mkIf (!cfg.readOnly) {
        path = [
          pkgs.findutils
          pkgs.rsync
        ];
        unitConfig.RequiresMountsFor = [
          "/mnt/cache"
          "/mnt/user0"
        ];
        serviceConfig.Type = "oneshot";
        script = ''
          cd /mnt/cache
          find ${lib.escapeShellArgs moved} -type f -mmin +1440 \
            ! -name '*-wal' ! -name '*-shm' ! -name '*-journal' -print0 \
            | rsync -aHAX --from0 --files-from=- --remove-source-files --preallocate . /mnt/user0/
        '';
      };
    };

    systemd.timers.nas-mover = lib.mkIf (!cfg.readOnly) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "03:30";
        Persistent = true;
      };
    };

    networking.firewall = {
      allowedTCPPorts = [
        111
        2049
        4000
        4001
        4002
      ];
      allowedUDPPorts = [
        111
        2049
        4000
        4001
        4002
      ];
    };
  };
}
