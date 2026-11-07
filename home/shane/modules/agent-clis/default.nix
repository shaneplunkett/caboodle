{
  pkgs,
  lib,
  ...
}:
let
  mkRbwWrapper = import ./mk-rbw-wrapper.nix { inherit lib pkgs; };
in
{
  home.packages = [
    (mkRbwWrapper {
      package = pkgs.browserbase-cli;
      secrets = [
        {
          var = "BROWSERBASE_API_KEY";
          entry = "browserbase-api-key";
        }
      ];
    })

    (mkRbwWrapper {
      package = pkgs.tavily-cli;
      secrets = [
        {
          var = "TAVILY_API_KEY";
          entry = "tavily-api-key";
        }
      ];
    })
  ];
}
