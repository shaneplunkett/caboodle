rec {
  name = "cache.home.arpa";
  port = 5000;
  url = "http://${name}:${toString port}";
  publicKey = "cache-1:iS3EWpPGVpZaFsXVfSBRCDvWlMZyk16CjJmzoSNUmtc=";
}
