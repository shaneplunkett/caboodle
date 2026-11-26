{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  workConfigDir = ".claude-work";
  workConfigPath = "${config.home.homeDirectory}/${workConfigDir}";
  workSettings = lib.escapeShellArg "${workConfigPath}/settings.json";
  personalInstructions = lib.escapeShellArg "${config.home.homeDirectory}/.claude/**";
  jq = lib.getExe pkgs.jq;
  princessSkills =
    lib.intersectAttrs (builtins.readDir "${inputs.ai-skills}/princess")
      inputs.ai-skills.lib.skills.${pkgs.stdenv.hostPlatform.system};
in
{
  options.vex.ai.claude.workConfigDir = lib.mkOption {
    type = lib.types.str;
    description = "Home-relative Claude Code config directory for the work account.";
  };

  config = {
    vex.ai.claude = { inherit workConfigDir; };

    home.file = {
      "${workConfigDir}/skills/paper-desktop".source = "${inputs.paper-plugins}/plugins/paper-desktop";
    }
    // lib.mapAttrs' (
      name: source: lib.nameValuePair "${workConfigDir}/skills/${name}" { inherit source; }
    ) princessSkills;

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
      };

      fish.shellAliases.ccw = "CLAUDE_CONFIG_DIR=$HOME/${workConfigDir} claude --dangerously-skip-permissions";
    };
  };
}
