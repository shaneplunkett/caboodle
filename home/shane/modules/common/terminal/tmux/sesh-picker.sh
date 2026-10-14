# shellcheck shell=bash
set -u

CONFIG="${SESH_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/sesh/sesh.toml}"
LOG="${XDG_CACHE_HOME:-$HOME/.cache}/sesh-picker.log"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/sesh-picker"
PREVIOUS_WORKSPACE_FILE="$STATE_DIR/previous-workspace"
FZF_THEME=(
  --ansi
  --no-separator
  --info=inline-right
  --prompt='workspace > '
  --pointer='▌'
  --marker='•'
  --scrollbar='▐▌'
  --color='bg:-1,bg+:#45475a,gutter:-1,fg:#cdd6f4,fg+:#f5c2e7,hl:#cba6f7,hl+:#f5c2e7,prompt:#f5c2e7,pointer:#f5c2e7,marker:#a6e3a1,header:#cba6f7,info:#89b4fa,query:#f5e0dc,spinner:#f9e2af'
)

list_workspaces() {
  local previous_workspace
  previous_workspace="$(
    if [ -n "${TMUX_PICKER_PREVIOUS_WORKSPACE:-}" ]; then
      printf '%s\n' "$TMUX_PICKER_PREVIOUS_WORKSPACE"
    elif [ -r "$PREVIOUS_WORKSPACE_FILE" ]; then
      sed -n '1p' "$PREVIOUS_WORKSPACE_FILE"
    else
      true
    fi
  )"

  sesh -C "$CONFIG" list -t -c 2>>"$LOG" | awk -v previous="$previous_workspace" '
    $0 == "" || seen[$0]++ {
      next
    }
    previous != "" && $0 == previous {
      previous_seen = 1
      next
    }
    previous == "scratch" && $0 == "home" {
      scratch = "scratch"
    }
    $0 == "scratch" {
      scratch = $0
      next
    }
    {
      workspaces[++workspace_count] = $0
    }
    END {
      if (previous_seen) {
        print previous
      }
      for (i = 1; i <= workspace_count; i++) {
        print workspaces[i]
      }
      if (scratch != "") {
        if (!previous_seen || scratch != previous) {
          print scratch
        }
      } else if (previous != "scratch") {
        print "scratch"
      }
    }
  '
}

find_projects() {
  {
    printf '%s\n' "$HOME"
    printf '%s\n' "$HOME/nix-config"
    printf '%s\n' "$HOME/ai-skills"
    fd -H -t d -d 1 \
      -E .git -E node_modules -E .direnv -E .next -E dist \
      . "$HOME/Projects/personal" 2>/dev/null
  } | awk '!seen[$0]++'
}

pick_project() {
  find_projects | fzf "${FZF_THEME[@]}" \
    --no-sort \
    --prompt='project > ' \
    --height='100%'
}

expand_path() {
  if [[ $1 == "~" ]]; then
    printf '%s\n' "$HOME"
  elif [[ $1 == \~/* ]]; then
    printf '%s/%s\n' "$HOME" "${1:2}"
  elif [[ $1 == /* ]]; then
    printf '%s\n' "$1"
  else
    printf '%s/%s\n' "$PWD" "$1"
  fi
}

open_path() {
  local input path
  printf 'Workspace path: '
  read -r input
  [ -z "$input" ] && return

  path="$(expand_path "$input")"
  if [ ! -d "$path" ]; then
    printf 'No directory at %s.\n\nPress enter to return.' "$path"
    read -r _
    return
  fi

  connect_workspace "$path"
}

current_workspace() {
  tmux display-message -p '#S' 2>/dev/null || true
}

remember_previous_workspace() {
  local target=$1 current
  current="$(current_workspace)"
  [ -z "$current" ] && return
  [ "$current" = "$target" ] && return

  mkdir -p "$STATE_DIR"
  printf '%s\n' "$current" >"$PREVIOUS_WORKSPACE_FILE"
}

rename_workspace() {
  local old_name=$1
  if ! tmux has-session -t "$old_name" 2>/dev/null; then
    printf 'Only live tmux sessions can be renamed.\n\nPress enter to return.'
    read -r _
    return
  fi

  printf 'Rename %s to: ' "$old_name"
  read -r new_name
  [ -z "$new_name" ] && return
  tmux rename-session -t "$old_name" "$new_name"
}

kill_workspace() {
  local name=$1
  if ! tmux has-session -t "$name" 2>/dev/null; then
    printf 'No live tmux session named %s.\n\nPress enter to return.' "$name"
    read -r _
    return
  fi

  printf 'Kill %s? [y/N] ' "$name"
  read -r confirm
  case "$confirm" in
    y|Y|yes|YES) tmux kill-session -t "$name" ;;
  esac
}

connect_workspace() {
  local name=$1
  [ -z "$name" ] && return
  remember_previous_workspace "$name"
  sesh -C "$CONFIG" connect --switch "$name"
}

main() {
  mkdir -p "$(dirname "$LOG")"
  : >"$LOG"

  while true; do
    selection="$(
      list_workspaces | fzf "${FZF_THEME[@]}" \
        --no-sort \
        --header='ctrl-f find | ctrl-o path | ctrl-r rename | ctrl-d kill' \
        --header-first \
        --expect='ctrl-f,ctrl-o,ctrl-r,ctrl-d'
    )"

    status=$?
    [ "$status" -ne 0 ] && exit "$status"

    key="$(printf '%s\n' "$selection" | sed -n '1p')"
    choice="$(printf '%s\n' "$selection" | sed -n '2p')"

    case "$key" in
      ctrl-f)
        project="$(pick_project)"
        [ -n "${project:-}" ] && connect_workspace "$project"
        exit $?
        ;;
      ctrl-o)
        open_path
        exit $?
        ;;
      ctrl-r)
        [ -n "$choice" ] && rename_workspace "$choice"
        ;;
      ctrl-d)
        [ -n "$choice" ] && kill_workspace "$choice"
        ;;
      *)
        connect_workspace "$choice"
        exit $?
        ;;
    esac
  done
}

main
