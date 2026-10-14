{
  config,
  pkgs,
  lib,
  aiHelpers,
  ...
}:
let
  inherit (config.home) homeDirectory;

  tomlFormat = pkgs.formats.toml { };

  mkBashHook =
    {
      name,
      runtimeInputs ? [ ],
      script,
    }:
    pkgs.writeShellApplication {
      inherit name;
      runtimeInputs = [
        pkgs.bash
        pkgs.coreutils
      ]
      ++ runtimeInputs;
      text = ''exec bash ${script} "$@"'';
    };

  codex-emit-context = mkBashHook {
    name = "codex-emit-context";
    runtimeInputs = [ pkgs.jq ];
    script = ./codex-emit-context.sh;
  };

  codexPackage = pkgs.codex;
  codexConfigDir = ".codex";
  codexCodeConfigDir = ".codex-code";
  # Vanilla home: same account auth as the main dir, but none of the managed
  # context, skills, hooks, or MCP servers land here. Used for PR reviews via
  # the Codex plugin for Claude Code (CODEX_HOME) and the Codex Bare provider.
  codexBareConfigDir = ".codex-bare";
  codexMcpServer =
    _name: server:
    let
      isHttp = (server.url or null) != null;
      alwaysStripKeys = [
        # Codex accepts bearer_token_env_var and headers, but rejects a literal
        # bearer_token even for HTTP transports.
        "bearer_token"
        "disabled"
        "headers"
        # Shared MCP entries may carry OAuth metadata that Codex treats as an
        # instruction to start an OAuth flow during initialisation.
        "oauth"
        "oauth_resource"
        "type"
      ];
      stdioOnlyKeys = [
        "args"
        "command"
        "cwd"
        "env"
        "env_vars"
      ];
      httpOnlyKeys = [
        "bearer_token_env_var"
        "env_http_headers"
        "http_headers"
        "url"
      ];
      transportKeys = if isHttp then stdioOnlyKeys else httpOnlyKeys;
      headers = server.headers or { };
    in
    (lib.filterAttrs (_: value: value != null) (
      lib.removeAttrs server (alwaysStripKeys ++ transportKeys)
    ))
    // (lib.optionalAttrs (isHttp && headers != { }) {
      http_headers = headers;
    })
    // {
      enabled = !(server.disabled or false);
    };

  transformedMcpServers = lib.optionalAttrs config.programs.mcp.enable (
    lib.mapAttrs codexMcpServer config.programs.mcp.servers
  );

  sharedCodexHooks = aiHelpers.hooksFor "codex";

  # The main profile adds Vex's session context on top of the shared hooks.
  codexHooks = sharedCodexHooks // {
    SessionStart = (sharedCodexHooks.SessionStart or [ ]) ++ [
      {
        hooks = [
          {
            type = "command";
            command = "${codex-emit-context}/bin/codex-emit-context SessionStart ${aiHelpers.prompts.vexSessionStartFile}";
            timeout = 10;
          }
        ];
      }
    ];
  };

  codexSettings = {
    model = "gpt-5.6-sol";
    model_reasoning_effort = "high";
    project_doc_max_bytes = 65536;

    agents.max_concurrent_threads_per_session = 10;

    features = {
      chronicle = false;
      hooks = true;
      memories = false;

      # GPT-5.6 Sol's reserved collaboration.spawn_agent schema hides custom
      # agent and model routing. Use a non-reserved namespace until upstream
      # fixes openai/codex#31814 and #32031.
      multi_agent_v2 = {
        hide_spawn_agent_metadata = false;
        tool_namespace = "agents";
      };
    };

    plugins = {
      "chrome@openai-bundled".enabled = false;
      "documents@openai-primary-runtime".enabled = false;
      "pdf@openai-primary-runtime".enabled = false;
      "presentations@openai-primary-runtime".enabled = false;
      "sites@openai-bundled".enabled = false;
      "spreadsheets@openai-primary-runtime".enabled = false;
      "template-creator@openai-primary-runtime".enabled = false;
      "visualize@openai-bundled".enabled = false;
    };

    skills.config =
      map
        (path: {
          inherit path;
          enabled = false;
        })
        [
          "${homeDirectory}/${codexConfigDir}/skills/.system/imagegen/SKILL.md"
          "${homeDirectory}/${codexConfigDir}/skills/.system/plugin-creator/SKILL.md"
          "${homeDirectory}/${codexConfigDir}/skills/chronicle/SKILL.md"
        ];

    memories = {
      generate_memories = false;
      use_memories = false;
    };

    tui = {
      theme = "catppuccin-mocha";
      status_line = [
        "model-with-reasoning"
        "project-name"
        "git-branch"
        "run-state"
        "context-remaining"
        "task-progress"
      ];
      terminal_title = [
        "activity"
        "project-name"
        "git-branch"
        "thread-title"
      ];
    };

    shell_environment_policy."inherit" = "all";

    sandbox_mode = "danger-full-access";
    approval_policy = "never";

    projects."/home/shane/nix-config".trust_level = "trusted";

    hooks = codexHooks;
  }
  // lib.optionalAttrs (transformedMcpServers != { }) {
    mcp_servers = transformedMcpServers;
  };

  codexConfigSeed = tomlFormat.generate "codex-config.toml" codexSettings;

  codeGirlySettings = codexSettings // {
    hooks = sharedCodexHooks;
    skills.config =
      map
        (path: {
          inherit path;
          enabled = false;
        })
        [
          "${homeDirectory}/${codexCodeConfigDir}/skills/.system/imagegen/SKILL.md"
          "${homeDirectory}/${codexCodeConfigDir}/skills/.system/plugin-creator/SKILL.md"
          "${homeDirectory}/${codexCodeConfigDir}/skills/chronicle/SKILL.md"
        ];
  };

  codeGirlyConfigSeed = tomlFormat.generate "codex-code-config.toml" codeGirlySettings;

  mutableCodexHomes = [
    {
      dir = codexConfigDir;
      seed = codexConfigSeed;
    }
    {
      dir = codexCodeConfigDir;
      seed = codeGirlyConfigSeed;
    }
  ];

  # Stock Codex apart from a pinned model and the remote plugin/app sync that
  # would otherwise populate the home on first app-server start.
  codexBareSettings = {
    model = "gpt-6-astra";
    model_reasoning_effort = "medium";

    features = {
      apps = false;
      memories = false;
      plugin_sharing = false;
      plugins = false;
      remote_plugin = false;
    };
  };

  codexBareConfigSeed = tomlFormat.generate "codex-bare-config.toml" codexBareSettings;

  codexConfigMerger = pkgs.writeShellApplication {
    name = "codex-config-merge";
    runtimeInputs = [
      (pkgs.python3.withPackages (pythonPackages: [ pythonPackages.tomli-w ]))
    ];
    text = ''
            exec python3 - "$@" <<'PY'
      import pathlib
      import sys
      import tomllib

      import tomli_w

      REPLACE_SUBTREES = {
          ("agents",),
          ("hooks",),
          ("mcp_servers",),
          ("memories",),
      }


      def read_toml(path):
          if not path.exists():
              return {}
          with path.open("rb") as fh:
              return tomllib.load(fh)


      def merge(base, managed):
          for key, value in managed.items():
              if isinstance(value, dict) and isinstance(base.get(key), dict):
                  merge(base[key], value)
              else:
                  base[key] = value
          return base


      def delete_path(data, path):
          cursor = data
          for key in path[:-1]:
              child = cursor.get(key)
              if not isinstance(child, dict):
                  return
              cursor = child
          cursor.pop(path[-1], None)


      def leaf_paths(data, prefix=()):
          for key, value in data.items():
              path = prefix + (key,)
              if isinstance(value, dict):
                  yield from leaf_paths(value, path)
              else:
                  yield path


      managed_path = pathlib.Path(sys.argv[1])
      target_path = pathlib.Path(sys.argv[2])

      managed = read_toml(managed_path)
      target = read_toml(target_path)

      for path in REPLACE_SUBTREES:
          delete_path(target, path)
      for path in leaf_paths(managed):
          is_replaced_subtree = any(
              path[: len(subtree)] == subtree for subtree in REPLACE_SUBTREES
          )
          if not is_replaced_subtree:
              delete_path(target, path)

      target_path.parent.mkdir(parents=True, exist_ok=True)
      target_path.write_bytes(tomli_w.dumps(merge(target, managed)).encode())
      PY
    '';
  };

  mutableConfigActivation =
    { dir, seed }:
    let
      configPath = "${homeDirectory}/${dir}/config.toml";
      managedConfigPath = "${homeDirectory}/${dir}/managed_config.toml";
      rulesPath = "${homeDirectory}/${dir}/rules/default.rules";
    in
    ''
      $DRY_RUN_CMD mkdir -p "${homeDirectory}/${dir}/rules"

      if [ -L "${configPath}" ]; then
        $DRY_RUN_CMD rm "${configPath}"
      fi
      if [ -f "${configPath}" ]; then
        $DRY_RUN_CMD chmod u+w "${configPath}"
      fi
      if [ -z "''${DRY_RUN_CMD:-}" ]; then
        ${codexConfigMerger}/bin/codex-config-merge "${seed}" "${configPath}"
      else
        $DRY_RUN_CMD merge managed Codex settings into "${configPath}"
      fi

      for legacyFile in \
        "${managedConfigPath}" \
        "${homeDirectory}/${dir}/vex.config.toml" \
        "${homeDirectory}/${dir}/hooks.json"
      do
        if [ -L "$legacyFile" ]; then
          $DRY_RUN_CMD rm "$legacyFile"
        fi
      done

      if [ -L "${rulesPath}" ]; then
        $DRY_RUN_CMD rm "${rulesPath}"
      fi
      if [ ! -e "${rulesPath}" ]; then
        $DRY_RUN_CMD cp "${./default.rules}" "${rulesPath}"
        $DRY_RUN_CMD chmod u+w "${rulesPath}"
      fi
    '';

in
{
  # Published artifacts other modules consume (e.g. vex-code).
  options.vex.ai.codex = {
    configDir = lib.mkOption {
      type = lib.types.str;
      description = "Home-relative Codex config directory.";
    };

    codeConfigDir = lib.mkOption {
      type = lib.types.str;
      description = "Home-relative Codex directory for the lightweight coding companion.";
    };

    bareConfigDir = lib.mkOption {
      type = lib.types.str;
      description = "Home-relative vanilla Codex directory sharing the main dir's auth.";
    };
  };

  config = {
    vex.ai.codex = {
      configDir = codexConfigDir;
      codeConfigDir = codexCodeConfigDir;
      bareConfigDir = codexBareConfigDir;
    };

    home = {
      file =
        (aiHelpers.mkSkillTree {
          dir = "${codexConfigDir}/skills";
          inherit (aiHelpers) skills;
        })
        // (aiHelpers.mkSkillTree {
          dir = "${codexCodeConfigDir}/skills";
          inherit (aiHelpers) skills;
        })
        // {
          "${codexCodeConfigDir}/AGENTS.md".text = aiHelpers.prompts.personal;
        };

      activation = {
        codexMutableConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] (
          lib.concatMapStringsSep "\n" mutableConfigActivation mutableCodexHomes
        );

        # Code Girly has her own writable Codex home and session history, but
        # shares the account token that Codex refreshes in the Vex home.
        codexCodeAuth = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          codeDir="${homeDirectory}/${codexCodeConfigDir}"
          $DRY_RUN_CMD mkdir -p "$codeDir"
          if [ ! -e "$codeDir/auth.json" ] && [ ! -L "$codeDir/auth.json" ]; then
            $DRY_RUN_CMD ln -s "${homeDirectory}/${codexConfigDir}/auth.json" "$codeDir/auth.json"
          fi
        '';

        # Codex rewrites auth.json in place on token refresh, so a symlink
        # keeps the bare home on the same account with a single credential
        # file rather than a copy that drifts. config.toml is merged rather
        # than linked so Codex can still write runtime fields into it.
        codexBareHome = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          bareDir="${homeDirectory}/${codexBareConfigDir}"
          $DRY_RUN_CMD mkdir -p "$bareDir"
          if [ ! -e "$bareDir/auth.json" ] && [ ! -L "$bareDir/auth.json" ]; then
            $DRY_RUN_CMD ln -s "${homeDirectory}/${codexConfigDir}/auth.json" "$bareDir/auth.json"
          fi
          if [ -z "''${DRY_RUN_CMD:-}" ]; then
            ${codexConfigMerger}/bin/codex-config-merge "${codexBareConfigSeed}" "$bareDir/config.toml"
          else
            $DRY_RUN_CMD merge managed Codex settings into "$bareDir/config.toml"
          fi
        '';
      };
    };

    programs = {
      codex = {
        enable = true;
        package = codexPackage;

        context = aiHelpers.prompts.vexCodex;
        skills = { };
        settings = { };
        rules = { };
      };
    };
  };
}
