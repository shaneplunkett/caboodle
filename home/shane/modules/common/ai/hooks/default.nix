# Each script is run as `<script> <harness>` with the hook payload on stdin.
{ pkgs, lib }:
let
  matchers = {
    claude = {
      shell = "Bash";
      edit = "Edit|Write|MultiEdit";
    };
    codex = {
      shell = "exec_command|functions.exec_command|Bash|shell";
      edit = "^apply_patch$";
    };
  };

  changedFiles = pkgs.writeShellApplication {
    name = "hook-changed-files";
    runtimeInputs = [ pkgs.jq ];
    text = "exec jq -r -f ${./changed-files.jq}";
  };

  sharedHooks = [
    {
      name = "git-commit-guard";
      event = "PreToolUse";
      tool = "shell";
      script = ./git-commit-guard.sh;
      runtimeInputs = [
        pkgs.git
        pkgs.gnugrep
        pkgs.gnused
      ];
    }
    {
      name = "pr-merge-guard";
      event = "PreToolUse";
      tool = "shell";
      script = ./pr-merge-guard.sh;
      runtimeInputs = [
        pkgs.gh
        pkgs.gnugrep
        pkgs.gnused
      ];
      timeout = 20;
    }
    {
      name = "rbw-locked";
      event = "SessionStart";
      script = ./rbw-locked.sh;
      runtimeInputs = [ pkgs.rbw ];
    }
    {
      name = "markdown-table-width";
      event = "PostToolUse";
      tool = "edit";
      script = ./markdown-table-width.sh;
      runtimeInputs = [
        pkgs.git
        pkgs.gnugrep
      ];
    }
  ];

  vexHooks = [
    {
      name = "vex-boot";
      event = "SessionStart";
      script = ./vex-boot.sh;
      timeout = 15;
    }
  ];

  hookPackage =
    harness:
    {
      name,
      script,
      runtimeInputs ? [ ],
      ...
    }:
    pkgs.writeShellApplication {
      name = "${harness}-${name}";
      runtimeInputs = [
        pkgs.coreutils
        pkgs.jq
        changedFiles
      ]
      ++ runtimeInputs;
      text = ''exec ${pkgs.bash}/bin/bash ${script} ${harness} "$@"'';
    };

  mkHook =
    harness: command:
    {
      event,
      tool ? null,
      timeout ? 10,
      ...
    }:
    {
      inherit event;
      entry = lib.optionalAttrs (tool != null) { matcher = matchers.${harness}.${tool}; } // {
        hooks = [
          {
            type = "command";
            inherit command timeout;
          }
        ];
      };
    };

  hooksIn =
    harness: commandOf: hooks:
    lib.mapAttrs (_: map (hook: hook.entry)) (
      lib.groupBy (hook: hook.event) (map (hook: mkHook harness (commandOf hook) hook) hooks)
    );

  storeCommand = harness: hook: lib.getExe (hookPackage harness hook);

  linkedHooksIn =
    harness: hooks:
    { homeDirectory, dir }:
    let
      linkPath = hook: "${dir}/${harness}-${hook.name}";
    in
    {
      hooks = hooksIn harness (hook: "${homeDirectory}/${linkPath hook}") hooks;
      files = lib.listToAttrs (
        map (hook: lib.nameValuePair (linkPath hook) { source = storeCommand harness hook; }) hooks
      );
    };
in
{
  vexHooksFor = harness: hooksIn harness (storeCommand harness) (sharedHooks ++ vexHooks);
  linkedHooksFor = harness: linkedHooksIn harness sharedHooks;
  linkedVexHooksFor = harness: linkedHooksIn harness (sharedHooks ++ vexHooks);
}
