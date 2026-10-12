{ secrets }:
let
  api = "https://photos.shaneplunkett.com/api";
  headers."x-api-key"._secret = secrets.immich-glance-api-key.path;
in
{
  type = "custom-api";
  title = "Photos";
  title-url = "https://photos.shaneplunkett.com";
  cache = "5m";
  url = "${api}/server/statistics";
  inherit headers;
  subrequests = {
    queues = {
      url = "${api}/queues";
      inherit headers;
    };
    memories = {
      url = "${api}/memories";
      inherit headers;
    };
    newest = {
      url = "${api}/search/metadata";
      method = "POST";
      inherit headers;
      body-type = "json";
      body = {
        orderBy = {
          field = "fileCreatedAt";
          direction = "desc";
        };
        size = 1;
      };
    };
  };
  template = builtins.readFile ./template.html;
}
