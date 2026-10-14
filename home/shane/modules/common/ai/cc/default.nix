{
  pkgs,
  aiHelpers,
  ...
}:
{
  programs = {
    claude-code = {
      enable = true;
      package = pkgs.claude-code;
      context = aiHelpers.prompts.personal;
      enableMcpIntegration = true;
      inherit (aiHelpers) skills;

      settings = {
        feedbackSurveyRate = 0;
        autoMemoryEnabled = false;
        model = "opus";
        extraKnownMarketplaces.openai-codex.source = {
          source = "github";
          repo = "openai/codex-plugin-cc";
        };
        enabledPlugins."codex@openai-codex" = true;
        hooks = aiHelpers.hooksFor "claude";
      };
    };

    fish.shellAliases = {
      cc = "claude --dangerously-skip-permissions";
      ccr = "claude --dangerously-skip-permissions --resume";
    };
  };
}
