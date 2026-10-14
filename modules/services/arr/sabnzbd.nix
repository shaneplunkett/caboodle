{ config, ... }:
let
  cfg = config.services.sabnzbd;
  dataDir = "/var/lib/${cfg.stateDir}";
  downloads = "/mnt/media/downloads";
in
{
  homelab = {
    secrets = [ "sabnzbd" ];
    routes.nzb = cfg.settings.misc.port;

    backup = {
      paths = [ dataDir ];
      exclude = [
        "${dataDir}/logs"
        "${dataDir}/sabnzbd.ini"
      ];
    };

    arr.databases = [ "${dataDir}/admin/history1.db" ];
  };

  age.secrets.sabnzbd.owner = cfg.user;

  services.sabnzbd = {
    enable = true;
    openFirewall = true;
    secretFiles = [ config.age.secrets.sabnzbd.path ];
    allowConfigWrite = true;

    settings = {
      misc = {
        host = "0.0.0.0";
        url_base = "/sabnzbd";
        host_whitelist = "nzb.shaneplunkett.com, arr";
        inet_exposure = 5;
        download_dir = "${downloads}/usenet/incomplete";
        complete_dir = "${downloads}/usenet/complete";
        bandwidth_max = "500M";
        bandwidth_perc = 100;
        cache_limit = "1G";
        direct_unpack = true;
      };

      servers."news.easynews.com" = {
        name = "news.easynews.com";
        displayname = "news.easynews.com";
        host = "news.easynews.com";
        port = 563;
        connections = 8;
      };

      categories = {
        "*" = {
          name = "*";
          order = 0;
          pp = 3;
          script = "None";
          priority = 0;
        };
        movies = {
          name = "movies";
          order = 0;
          priority = -100;
        };
        tv = {
          name = "tv";
          order = 0;
          priority = -100;
        };
        audio = {
          name = "audio";
          order = 0;
          priority = -100;
        };
        software = {
          name = "software";
          order = 0;
          priority = -100;
        };
        anime = {
          name = "anime";
          order = 1;
          priority = -100;
        };
        shelfarr = {
          name = "shelfarr";
          order = 2;
          priority = -100;
          dir = "${downloads}/books-ingest";
        };
      };
    };
  };
}
