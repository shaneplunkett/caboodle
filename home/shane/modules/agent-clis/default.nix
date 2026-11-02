{
  pkgs,
  lib,
  osConfig,
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
      package = pkgs.langsmith-cli;
      secrets = [
        {
          var = "LANGSMITH_API_KEY";
          entry = "langsmith-api-key";
        }
      ];
      extraEnv.LANGSMITH_ENDPOINT = "https://api.smith.langchain.com";
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

    (mkRbwWrapper {
      package = pkgs.todoist-cli;
      secrets = [
        {
          var = "TODOIST_API_TOKEN";
          entry = "todoist-api-token";
        }
      ];
    })

    (mkRbwWrapper {
      package = pkgs.unifi-cli;
      secrets = [
        {
          var = "UNIFI_API_KEY";
          entry = "Unifi API Key";
        }
      ];
      extraEnv.UNIFI_CONTROLLER_URL = "https://${osConfig.homelab.gateway}";
    })
  ];
}
