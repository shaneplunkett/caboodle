{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  fish = lib.getExe config.programs.fish.package;

  # Every Mac the flake can switch, matched against this machine's names.
  darwinHosts = lib.concatStringsSep " " (lib.attrNames inputs.self.darwinConfigurations);

  # The login shell stays bash (Linux) or zsh (macOS), so agents and scripts
  # get a POSIX-ish shell; interactive shells hand over to fish. `-c`
  # commands, nix develop/nix-shell, and a shell typed from fish all stay
  # put. nix develop applies its environment after the rc file, so it must
  # stay; a direnv environment is already exported (DIRENV_DIR) and survives
  # the exec.
  handOverToFish =
    { executionString, isLogin }:
    lib.mkBefore ''
      parent=$(ps -o comm= -p "$PPID" 2>/dev/null)
      parent=''${parent##*/}
      if [[ ''${parent#-} != fish && -z ''${${executionString}:-} ]] &&
        [[ -z ''${IN_NIX_SHELL:-} || -n ''${DIRENV_DIR:-} ]]; then
        ${isLogin} && exec ${fish} --login
        exec ${fish}
      fi
      unset parent
    '';
in
{
  programs = {
    bash = {
      enable = true;
      initExtra = handOverToFish {
        executionString = "BASH_EXECUTION_STRING";
        isLogin = "shopt -q login_shell";
      };
    };

    zsh = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
      enable = true;
      initContent = handOverToFish {
        executionString = "ZSH_EXECUTION_STRING";
        isLogin = "[[ -o login ]]";
      };
    };

    fish = {
      enable = true;
      shellAliases = {
        cx = "codex";
        cxr = "codex resume --last";
        cxb = "CODEX_HOME=$HOME/.codex-bare codex";
      };
      shellAbbrs = {
        cat = "bat";
        ngc = "nh clean all --keep 3 --keep-since 7d --ask";
        tfi = "terraform init";
        tfp = "terraform plan";
        tfa = "terraform apply";
        tfaa = "terraform apply -auto-approve";
        nvl = "nvim --listen /tmp/nvim";
      };
      functions = {
        tmux = ''
          if test (count $argv) -eq 0
            command tmux new-session -A -s scratch
          else
            command tmux $argv
          end
        '';
        __nrs_darwin_host = ''
          if set -q NRS_HOST
            echo $NRS_HOST
            return 0
          end

          set -l candidates
          if command -sq scutil
            for key in LocalHostName HostName
              set -l value (scutil --get $key 2>/dev/null)
              if test -n "$value"
                set -a candidates $value
              end
            end
          end

          set -a candidates (hostname -s 2>/dev/null) (hostname 2>/dev/null)
          for candidate in $candidates
            switch $candidate
              case ${darwinHosts}
                echo $candidate
                return 0
            end
          end

          set -l tried (string join ', ' $candidates)
          echo "nrs: could not resolve this Mac to a darwinConfigurations host. Tried: $tried" >&2
          return 1
        '';
        refresh-fish = ''
          function __refresh_fish_on_signal --on-variable __nix_config_fish_refresh_generation
            status is-interactive; or return
            set -q __refresh_fish_broadcasting; and return
            refresh-fish --quiet
          end

          set -l quiet 0
          if test (count $argv) -gt 0
            switch $argv[1]
              case -q --quiet
                set quiet 1
              case '*'
                echo "refresh-fish: unknown argument $argv[1]" >&2
                return 2
            end
          end

          set -l config "$HOME/.config/fish/config.fish"
          if not test -f "$config"
            echo "refresh-fish: missing $config" >&2
            return 1
          end

          for function_file in "$HOME"/.config/fish/functions/*.fish
            test -e "$function_file"; or continue
            source "$function_file"
          end

          set -l in_reloadable_block 0
          while read -l line
            switch "$line"
              case '    # Abbreviations' '    # Aliases'
                set in_reloadable_block 1
                continue
              case '    # *'
                set in_reloadable_block 0
            end

            if test $in_reloadable_block -eq 1
              set -l trimmed (string trim "$line")
              if string match -qr '^(abbr --add|alias) ' -- "$trimmed"
                eval "$trimmed"
              end
            end
          end < "$config"

          if test $quiet -eq 0
            echo "fish aliases, abbreviations, and functions refreshed"
          end
        '';
        refresh-fish-all = ''
          set -l quiet 0
          if test (count $argv) -gt 0
            switch $argv[1]
              case -q --quiet
                set quiet 1
              case '*'
                echo "refresh-fish-all: unknown argument $argv[1]" >&2
                return 2
            end
          end

          refresh-fish --quiet; or return $status

          set -g __refresh_fish_broadcasting 1
          set -U __nix_config_fish_refresh_generation (command date +%s):(random):$fish_pid
          set -e __refresh_fish_broadcasting

          if test $quiet -eq 0
            echo "fish refresh signal sent to listening shells"
          end
        '';
        nrs = ''
          set -l switch_status

          if test (uname) = Darwin
            set -l host (__nrs_darwin_host); or return 1
            nh darwin switch $argv "$HOME/nix-config" -H $host
            set switch_status $status
          else
            nh os switch $argv "$HOME/nix-config" -H (hostname)
            set switch_status $status
          end

          if test $switch_status -eq 0
            refresh-fish-all --quiet
          end

          return $switch_status
        '';
      };
      generateCompletions = true;
      interactiveShellInit = ''
        function __refresh_fish_on_signal --on-variable __nix_config_fish_refresh_generation
          status is-interactive; or return
          set -q __refresh_fish_broadcasting; and return
          refresh-fish --quiet
        end

        set fish_greeting
        set -gx PATH $HOME/go/bin $PATH
        set -gx LS_COLORS "di=38;2;180;190;254:ln=38;2;203;166;247:so=38;2;245;194;231:pi=38;2;242;205;205:ex=38;2;166;227;161:bd=38;2;249;226;175:cd=38;2;249;226;175:su=38;2;166;227;161;48;2;30;30;46:sg=38;2;166;227;161;48;2;30;30;46:tw=38;2;180;190;254;48;2;30;30;46:ow=38;2;180;190;254:st=38;2;180;190;254;48;2;30;30;46:or=38;2;243;139;168:mi=38;2;243;139;168;48;2;30;30;46:*.tar=38;2;250;179;135:*.gz=38;2;250;179;135:*.zip=38;2;250;179;135:*.7z=38;2;250;179;135:*.bz2=38;2;250;179;135:*.xz=38;2;250;179;135:*.zst=38;2;250;179;135:*.deb=38;2;250;179;135:*.rpm=38;2;250;179;135:*.nix=38;2;148;226;213:*.json=38;2;249;226;175:*.yaml=38;2;249;226;175:*.yml=38;2;249;226;175:*.toml=38;2;249;226;175:*.md=38;2;205;214;244:*.txt=38;2;205;214;244:*.rs=38;2;250;179;135:*.go=38;2;137;220;235:*.py=38;2;249;226;175:*.js=38;2;249;226;175:*.ts=38;2;137;180;250:*.lua=38;2;137;180;250:*.sh=38;2;166;227;161:*.fish=38;2;166;227;161"
        set -gx EZA_COLORS "ur=38;2;166;227;161:uw=38;2;249;226;175:ux=38;2;243;139;168:ue=38;2;243;139;168:gr=38;2;166;227;161:gw=38;2;249;226;175:gx=38;2;243;139;168:tr=38;2;166;227;161:tw=38;2;249;226;175:tx=38;2;243;139;168:sn=38;2;166;227;161:sb=38;2;166;227;161:nb=38;2;249;226;175:nk=38;2;166;227;161:nm=38;2;249;226;175:ng=38;2;250;179;135:nt=38;2;243;139;168:da=38;2;127;132;156:uu=38;2;180;190;254:gu=38;2;203;166;247:lp=38;2;203;166;247:ga=38;2;166;227;161:gm=38;2;249;226;175:gd=38;2;243;139;168:gv=38;2;148;226;213:gt=38;2;249;226;175"
      '';
    };
    fzf = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
