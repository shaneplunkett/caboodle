{ secrets }:
{
  type = "custom-api";
  title = "Unraid";
  title-url = "https://unraid.shaneplunkett.com";
  cache = "1m";
  url = "https://unraid.shaneplunkett.com/graphql";
  method = "POST";
  headers = {
    "x-api-key"._secret = secrets.unraid-api-key.path;
    Accept = "application/json";
  };
  body-type = "json";
  body.query = builtins.readFile ./query.graphql;
  skip-json-validation = true;
  template = builtins.readFile ./template.html;
}
