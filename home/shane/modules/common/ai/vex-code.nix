{
  config,
  lib,
  palette,
  ...
}:
let
  inherit (config.home) homeDirectory;
  inherit (palette) withHash;
  codex = lib.getExe config.programs.codex.package;
in
{
  programs.t3code.userSettings = {
    defaultModelSelection.instanceId = "claudeAgent";

    providerInstances = {
      codex = {
        driver = "codex";
        displayName = "Vex";
        accentColor = withHash.mauve;
        enabled = true;
        config = {
          enabled = true;
          binaryPath = codex;
          homePath = "${homeDirectory}/${config.vex.ai.codex.configDir}";
        };
      };

      codexCode = {
        driver = "codex";
        displayName = "Code Girly";
        accentColor = withHash.red;
        enabled = true;
        config = {
          enabled = true;
          binaryPath = codex;
          homePath = "${homeDirectory}/${config.vex.ai.codex.codeConfigDir}";
        };
      };

      codexBare = {
        driver = "codex";
        displayName = "Codex Bare";
        enabled = true;
        config = {
          enabled = true;
          binaryPath = codex;
          homePath = "${homeDirectory}/${config.vex.ai.codex.bareConfigDir}";
        };
      };

      claudeAgent = {
        driver = "claudeAgent";
        enabled = true;
        config = {
          enabled = true;
          binaryPath = lib.getExe config.programs.claude-code.finalPackage;
          # Empty so T3 leaves CLAUDE_CONFIG_DIR unset, matching the
          # terminal. Setting it, even to ~/.claude, moves the macOS
          # keychain entry to "Claude Code-credentials-<hash>" and the
          # spawned CLI reports "Not logged in". Kept as "" rather than
          # dropped because activation merges into the existing settings.
          homePath = "";
        };
      };
    };
  };
}
