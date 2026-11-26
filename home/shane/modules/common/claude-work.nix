{
  config,
  lib,
  pkgs,
  ...
}:
let
  workConfigDir = ".claude-work";
  workConfigPath = "${config.home.homeDirectory}/${workConfigDir}";
  workSettings = lib.escapeShellArg "${workConfigPath}/settings.json";
  personalInstructions = lib.escapeShellArg "${config.home.homeDirectory}/.claude/**";
  plugins = lib.escapeShellArg (
    builtins.toJSON {
      extraKnownMarketplaces.paper.source = {
        source = "github";
        repo = "paper-design/agent-plugins";
      };
      enabledPlugins."paper-desktop@paper" = true;
    }
  );
  merge = lib.escapeShellArg ''
    . * $plugins
    | .claudeMdExcludes = ((.claudeMdExcludes // []) | if index($p) then . else . + [$p] end)
  '';
  jq = lib.getExe pkgs.jq;
  cmp = lib.getExe' pkgs.diffutils "cmp";
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
        tmp="$(mktemp)"
        if ! ${jq} --arg p ${personalInstructions} --argjson plugins ${plugins} ${merge} ${workSettings} > "$tmp"; then
          echo "Couldn't update "${workSettings} >&2
        elif ! ${cmp} -s "$tmp" ${workSettings}; then
          mv "$tmp" ${workSettings}
        fi
        rm -f "$tmp"
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
