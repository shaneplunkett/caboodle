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
  workSettings = lib.escapeShellArg "${workConfigPath}/settings.json";
  personalInstructions = lib.escapeShellArg "${config.home.homeDirectory}/.claude/**";
  jq = lib.getExe pkgs.jq;
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
      if [ -z "''${DRY_RUN:-}" ]; then
        [ -s ${workSettings} ] || echo '{}' > ${workSettings}
        if ! ${jq} -e --arg p ${personalInstructions} '(.claudeMdExcludes // []) | index($p)' ${workSettings} > /dev/null; then
          tmp="$(mktemp)"
          if ${jq} --arg p ${personalInstructions} '.claudeMdExcludes = ((.claudeMdExcludes // []) + [$p])' ${workSettings} > "$tmp"; then
            mv "$tmp" ${workSettings}
          else
            rm -f "$tmp"
            echo "Couldn't add claudeMdExcludes to "${workSettings} >&2
          fi
        fi
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
