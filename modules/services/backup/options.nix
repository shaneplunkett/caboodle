{ lib, ... }:
{
  options.homelab.backup = {
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Data on this host to back up to the Storage Box.";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "restic exclude patterns for anything under the paths that shouldn't be kept.";
    };

    prepare = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Commands run before each backup, like dumping a database to a file under the paths.";
    };

    storageBox = lib.mkOption {
      type = lib.types.str;
      default = "u558795.your-storagebox.de";
      readOnly = true;
      description = "The Storage Box every host backs up to.";
    };

    r2Account = lib.mkOption {
      type = lib.types.str;
      default = "7d4e6e95bf7ff3d09d92e7903193826b";
      readOnly = true;
      description = "The Cloudflare account whose R2 holds each host's restic-<host> bucket.";
    };
  };
}
