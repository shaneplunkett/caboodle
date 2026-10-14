{
  config,
  lib,
  pkgs,
  palette,
  typography,
  ...
}:
let
  inherit (config.home) homeDirectory;
  inherit (palette) hex withHash;

  # Published as an environment theme; pick it once in Settings → Appearance.
  # The server opens theme files with O_NOFOLLOW, so the whole themes
  # directory is linked to the store and the file inside it stays real.
  catppuccinMocha = {
    name = "Catppuccin Mocha";
    appearance = "dark";
    colors = {
      canvas = withHash.base;
      chrome = withHash.mantle;
      toolbar = withHash.mantle;
      toolbarForeground = withHash.text;
      toolbarBorder = "#${hex.surface2}b8";
      toolbarControl = withHash.surface0;
      toolbarControlForeground = withHash.text;
      toolbarControlHover = withHash.surface1;
      surface = withHash.base;
      surfaceRaised = withHash.surface0;
      surfaceOverlay = withHash.mantle;
      inherit (withHash) text;
      textMuted = withHash.subtext0;
      border = "#${hex.surface2}b8";
      input = "#${hex.overlay0}b8";
      focus = withHash.mauve;
      accent = withHash.mauve;
      accentForeground = withHash.crust;
      secondary = withHash.surface0;
      secondaryForeground = withHash.text;
      muted = withHash.surface0;
      mutedForeground = withHash.subtext0;
      placeholder = withHash.overlay2;
      secondaryLabel = withHash.subtext0;
      iconMuted = withHash.overlay2;
      error = withHash.red;
      errorForeground = withHash.red;
      errorSurface = "#${hex.red}29";
      warning = withHash.yellow;
      warningForeground = withHash.yellow;
      warningSurface = "#${hex.yellow}29";
      update = withHash.mauve;
      updateForeground = withHash.mauve;
      updateSurface = "#${hex.mauve}2e";
      accentSurface = withHash.surface0;
      accentSurfaceForeground = withHash.text;
      messageSurface = withHash.surface0;
      messageForeground = withHash.text;
      messageAction = withHash.mauve;
      messageActionForeground = withHash.crust;
      messageActionHover = withHash.lavender;
      codeBackground = withHash.mantle;
      codeForeground = withHash.text;
      sidebar = withHash.mantle;
      sidebarForeground = withHash.text;
      sidebarMutedForeground = withHash.subtext0;
      sidebarControlSurface = withHash.surface0;
      sidebarRowHover = withHash.surface0;
      sidebarRowActive = withHash.surface1;
      sidebarRowSelected = withHash.surface0;
      sidebarBorder = "#${hex.surface2}b8";
      terminalBackground = withHash.base;
      terminalForeground = withHash.text;
      terminalCursor = withHash.lavender;
      terminalSelection = "#${hex.surface2}66";
      terminalScrollbar = "#${hex.surface2}4d";
      terminalScrollbarHover = "#${hex.overlay0}66";
    };
  };
in
{
  home.file.".t3/userdata/themes".source = pkgs.writeTextDir "catppuccin-mocha.json" (
    builtins.toJSON catppuccinMocha
  );

  programs.t3code = {
    enable = true;
    package = pkgs.vex-code;

    clientSettings = {
      fontFamilySans = typography.ui;
      fontFamilyCode = typography.codeMono;
      fontFamilyTerminal = typography.codeMono;
      fontSizeCode = 13;
      glassOpacity = 60;
      panelAnimationDurationMs = 25;
      timestampFormat = "12-hour";
      notificationMode = "notifications";
      followUpBehavior = "queue";
      contextWindowMeterEnabled = true;
      proactivePanelsEnabled = false;
      diffFilesCollapsed = false;
      browserAutoShowFloatingPreview = false;
      sidebarProjectSortOrder = "manual";
    };

    userSettings = {
      addProjectBaseDirectory = "~/Projects";
      enableProviderUpdateChecks = false;
      continueThreadsAfterServerUpdate = true;
      sidebarAutoSettleOnMerge = false;
      autoResumeLimitedThreads = true;
      automaticGitFetchInterval = 15000;
      providerHealthRefreshInterval = 60000;

      backgroundActivityProfile = "performance";
      backgroundActivity = {
        schemaVersion = 1;
        profile = "performance";
        overrides = { };
      };

      storageCleanup = {
        worktreeAfterDays = 8;
        worktreeOnMerge = true;
        worktreeOnDelete = true;
        browserArtifactsAfterDays = 3;
        logsAfterDays = 8;
      };

      defaultModelSelection = {
        instanceId = "claudeAgent";
        model = "claude-opus-5-5";
        options = [
          {
            id = "effort";
            value = "high";
          }
          {
            id = "contextWindow";
            value = "1m";
          }
        ];
      };

      providerInstances = {
        codex = {
          driver = "codex";
          displayName = "Vex";
          accentColor = withHash.mauve;
          enabled = true;
          config = {
            enabled = true;
            binaryPath = lib.getExe config.programs.codex.package;
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
            binaryPath = lib.getExe config.programs.codex.package;
            homePath = "${homeDirectory}/${config.vex.ai.codex.codeConfigDir}";
          };
        };

        # Vanilla instance: own CODEX_HOME with none of the personal context,
        # skills, hooks, or MCP servers, but auth.json is symlinked to ~/.codex
        # so both use the same account.
        codexBare = {
          driver = "codex";
          displayName = "Codex Bare";
          enabled = true;
          config = {
            enabled = true;
            binaryPath = lib.getExe config.programs.codex.package;
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
  };
}
