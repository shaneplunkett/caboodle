# Hooks shared by every AI harness. Declare a hook once in `sharedHooks`;
# `hooksFor "<harness>"` renders the settings shape Claude Code and Codex
# both use. Exposed through ../lib.nix as `aiHelpers.hooksFor`.
#
# Each script is run as `<script> <harness>` with the hook payload on stdin.
{ pkgs, lib }:
let
  # Tool-name matcher per harness for each kind of tool a hook can watch.
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

  # Print the paths a file-edit payload touched, one per line. Claude Code
  # sends tool_input.file_path; Codex sends the apply_patch text instead.
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

  mkHook =
    harness:
    {
      name,
      event,
      script,
      tool ? null,
      runtimeInputs ? [ ],
      timeout ? 10,
    }:
    let
      package = pkgs.writeShellApplication {
        name = "${harness}-${name}";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.jq
          changedFiles
        ]
        ++ runtimeInputs;
        text = ''exec ${pkgs.bash}/bin/bash ${script} ${harness} "$@"'';
      };
    in
    {
      inherit event;
      entry = lib.optionalAttrs (tool != null) { matcher = matchers.${harness}.${tool}; } // {
        hooks = [
          {
            type = "command";
            command = lib.getExe package;
            inherit timeout;
          }
        ];
      };
    };
in
{
  hooksFor =
    harness:
    lib.mapAttrs (_: map (hook: hook.entry)) (
      lib.groupBy (hook: hook.event) (map (mkHook harness) sharedHooks)
    );
}
