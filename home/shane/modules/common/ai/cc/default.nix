{ aiHelpers, ... }:
{
  programs = {
    claude-code = {
      context = aiHelpers.prompts.personal;
      enableMcpIntegration = true;
      inherit (aiHelpers) skills;

      settings = {
        feedbackSurveyRate = 0;
        autoMemoryEnabled = false;
        model = "opus";
        extraKnownMarketplaces = {
          openai-codex.source = {
            source = "github";
            repo = "openai/codex-plugin-cc";
          };
          paper.source = {
            source = "github";
            repo = "paper-design/agent-plugins";
          };
        };
        enabledPlugins = {
          "codex@openai-codex" = true;
          "paper-desktop@paper" = true;
        };
        hooks = aiHelpers.vexHooksFor "claude";
      };
    };

    fish.shellAliases = {
      cc = "claude --dangerously-skip-permissions";
      ccr = "claude --dangerously-skip-permissions --resume";
    };
  };
}
