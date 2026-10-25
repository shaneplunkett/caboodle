{
  config,
  nodes,
  pkgs,
  ...
}:
{
  homelab = {
    secrets = [
      "forge-bot-token"
      "renovate-github-token"
    ];
    monitoring.units = [ "renovate.service" ];
  };

  services.renovate = {
    enable = true;
    schedule = "06:30 Australia/Melbourne";
    runtimePackages = [
      pkgs.nodejs
      pkgs.pnpm
      pkgs.uv
      pkgs.go
      config.nix.package
    ];
    credentials = {
      RENOVATE_TOKEN = config.age.secrets.forge-bot-token.path;
      RENOVATE_GITHUB_COM_TOKEN = config.age.secrets.renovate-github-token.path;
    };
    settings = {
      platform = "forgejo";
      endpoint = "${nodes.forge.config.services.forgejo.settings.server.ROOT_URL}api/v1/";
      gitAuthor = "forge-bot <forge-bot@noreply.shaneplunkett.com>";
      autodiscover = true;
      autodiscoverNamespaces = [ "shane" ];
      minimumReleaseAge = "1 day";
      lockFileMaintenance.minimumReleaseAge = null;
      schedule = [ "before 9am on sunday" ];
      timezone = "Australia/Melbourne";
    };
  };
}
