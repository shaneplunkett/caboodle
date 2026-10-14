# CLIs the agent stack invokes, each wrapped to pull its API key from rbw at
# invocation.
{ pkgs, lib, ... }:
let
  mkRbwWrapper = import ./mk-rbw-wrapper.nix { inherit lib pkgs; };
in
{
  home.packages = [
    (import ./fj.nix { inherit lib pkgs; })
    (import ./tea.nix { inherit lib pkgs; })

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
      extraEnv = {
        UNIFI_CONTROLLER_URL = "https://192.168.1.1";
        UNIFI_SITE = "default";
        UNIFI_TIMEOUT = "10s";
      };
    })
  ];
}
