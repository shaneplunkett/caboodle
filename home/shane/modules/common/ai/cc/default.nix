{
  config,
  lib,
  pkgs,
  aiHelpers,
  ...
}:
let
  workConfigDir = ".claude-work";
  workConfigPath = "${config.home.homeDirectory}/${workConfigDir}";
in
{
  options.vex.ai.claude.workConfigDir = lib.mkOption {
    type = lib.types.str;
    description = "Home-relative Claude Code config directory for the work account.";
  };

  config = {
    vex.ai.claude = { inherit workConfigDir; };

    home.activation.claudeWorkHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p ${lib.escapeShellArg workConfigPath}
      if [ ! -e ${lib.escapeShellArg "${workConfigPath}/CLAUDE.md"} ]; then
        run touch ${lib.escapeShellArg "${workConfigPath}/CLAUDE.md"}
      fi
    '';

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
          hooks = aiHelpers.vexHooksFor "claude";
        };
      };

      fish.shellAliases = {
        cc = "claude --dangerously-skip-permissions";
        ccr = "claude --dangerously-skip-permissions --resume";
        ccw = "CLAUDE_CONFIG_DIR=$HOME/${workConfigDir} claude --dangerously-skip-permissions";
      };
    };
  };
}
