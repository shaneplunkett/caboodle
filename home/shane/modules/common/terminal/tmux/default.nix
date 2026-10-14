{
  lib,
  pkgs,
  palette,
  ...
}:
let
  inherit (palette) withHash;

  bg = "default";
  default_fg = withHash.text;
  session_fg = withHash.green;
  prefix_session_fg = withHash.peach;
  session_selection_fg = withHash.base;
  session_selection_bg = withHash.mauve;
  active_window_fg = withHash.mauve;
  active_pane_border = withHash.lavender;

  quote = value: ''"${value}"'';

  renderTmuxCommands = lib.concatStringsSep "\n";

  renderTmuxOptions =
    command: options: lib.mapAttrsToList (name: value: "${command} ${name} ${value}") options;

  renderBindings = bindings: map (binding: "bind ${binding.key} ${binding.command}") bindings;

  renderPopup =
    {
      key,
      title,
      width,
      height,
      command,
    }:
    "bind ${key} display-popup -E -w ${width} -h ${height} -d '#{pane_current_path}' -T '${title}' -S 'fg=${active_window_fg}' ${command}";

  workspaceStartupCommand = lib.concatStringsSep "; " [
    "tmux rename-window editor"
    ''tmux new-window -n server -c "{}"''
    ''tmux split-window -v -p 25 -c "{}"''
    "tmux select-pane -U"
    ''tmux new-window -n vex -c "{}"''
    "tmux select-window -t editor"
    "nvim"
  ];

  workspaceWildcards = [
    "~/Projects/personal/*"
  ];

  workspaceFor = pattern: {
    inherit pattern;
    startup_command = workspaceStartupCommand;
  };

  seshPicker = pkgs.writeShellApplication {
    name = "tmux-sesh-picker";
    runtimeInputs = with pkgs; [
      coreutils
      fd
      fzf
      gawk
      gnused
      sesh
      tmux
    ];
    text = builtins.readFile ./sesh-picker.sh;
  };

  tmuxPopupBindings = [
    {
      key = "o";
      title = "Vex Workspaces";
      width = "44%";
      height = "32%";
      command = lib.getExe seshPicker;
    }
    {
      key = "p";
      title = "Scratch";
      width = "80%";
      height = "80%";
      command = "${lib.getExe pkgs.fish} -l";
    }
  ];

  tmuxGlobalOptions = {
    "allow-passthrough" = "on";
    "message-command-style" = quote "bg=default,fg=${default_fg}";
    "message-style" = quote "bg=default,fg=${default_fg}";
    "mode-style" = quote "bg=${session_selection_bg},fg=${session_selection_fg}";
    "pane-active-border-style" = quote "fg=${active_pane_border},bg=default";
    "pane-border-style" = quote "fg=brightblack,bg=default";
    "renumber-windows" = "on";
    "status-justify" = "left";
    "status-left" =
      quote "#[fg=#{?client_prefix,${prefix_session_fg},${session_fg}},bold,bg=${bg}] #S #[fg=${default_fg},nobold,bg=${bg}] | ";
    "status-left-length" = "200";
    "status-position" = "top";
    "status-right" = quote "";
    "status-right-length" = "200";
    "status-style" = quote "bg=${bg}";
    "terminal-features" = quote ",xterm-256color:RGB";
    "window-status-current-format" = quote "#[fg=${active_window_fg},bold,bg=default]  #I:#W";
    "window-status-format" = quote "#[fg=${default_fg},bg=default] #I:#W";
    "window-status-last-style" = quote "fg=${default_fg},bg=default";
  };

  tmuxAppendGlobalOptions = {
    "terminal-features" = quote ",xterm-ghostty:RGB,usstyle";
  };

  tmuxKeyBindings = [
    {
      key = "r";
      command = ''source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded!"'';
    }
    {
      key = "'H'";
      command = ''split-window -v -c "#{pane_current_path}"'';
    }
    {
      key = "'V'";
      command = ''split-window -h -c "#{pane_current_path}"'';
    }
    {
      key = "w";
      command = ''new-window -c "#{pane_current_path}"'';
    }
  ];

  tmuxExtraConfig = renderTmuxCommands (
    (map (key: "unbind ${key}") [
      "r"
      "c"
      "%"
      "Space"
      "F"
      "P"
      "p"
      "s"
    ])
    ++ (map (key: "unbind -T root ${key}") [
      "C-M-b"
      "C-M-d"
      "C-M-e"
      "C-M-f"
      "C-M-r"
      "C-M-s"
      "C-M-u"
    ])
    ++ renderBindings tmuxKeyBindings
    ++ renderTmuxOptions "set -g" tmuxGlobalOptions
    ++ renderTmuxOptions "set -ga" tmuxAppendGlobalOptions
    ++ map renderPopup tmuxPopupBindings
  );
in
{
  programs = {
    sesh = {
      enable = true;
      enableAlias = false;
      enableTmuxIntegration = false;
      fzfPackage = null;
      icons = false;
      zoxidePackage = null;

      settings = {
        sort_order = [
          "config"
          "tmux"
        ];

        tui = {
          show_icons = false;
          prompt = "> ";
          placeholder = "Pick a workspace...";
        };

        session = [
          {
            name = "nix-config";
            path = "~/nix-config";
            startup_command = workspaceStartupCommand;
          }
          {
            name = "ai-skills";
            path = "~/ai-skills";
            startup_command = workspaceStartupCommand;
          }
          {
            name = "home";
            path = "~";
            startup_command = workspaceStartupCommand;
          }
          {
            name = "scratch";
            path = "~";
          }
        ];

        wildcard = map workspaceFor workspaceWildcards;
      };
    };

    tmux = {
      enable = true;
      shortcut = "a";
      baseIndex = 1;
      escapeTime = 0;
      shell = "${pkgs.fish}/bin/fish";
      newSession = false;
      keyMode = "vi";
      mouse = true;
      terminal = "tmux-256color";

      plugins = with pkgs.tmuxPlugins; [
        {
          plugin = vim-tmux-navigator;
        }
        {
          plugin = yank;
        }
      ];

      extraConfig = tmuxExtraConfig;
    };
  };
}
