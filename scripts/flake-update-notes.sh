#!/usr/bin/env bash
# The changelogs behind a flake bump, as markdown: what each upstream says
# changed between the old lock's rev and the new one's. The update workflow
# puts this in its pull request, and the flake-update skill triages it.
#
#   scripts/flake-update-notes.sh <old flake.lock> <new flake.lock>
#
# Only nixpkgs, home-manager, nix-darwin and omniwm have changelogs worth
# reading. Trees are fetched and diffed locally because GitHub's compare API
# drops files past 300. Uses git diff --no-index, not diff, because the
# builder has git and no diffutils.
set -euo pipefail

old_lock="$(cat "$1")"
new_lock="$(cat "$2")"
max_lines=400

rev() {
  jq -r --arg i "$2" '.nodes.root.inputs[$i] as $node | if $node then .nodes[$node].locked.rev else empty end' <<< "$1"
}

source_of() {
  jq -r --arg i "$1" '.nodes[.nodes.root.inputs[$i]].locked | "\(.owner)/\(.repo)"' <<< "$new_lock"
}

fetch() {
  nix flake prefetch --json "github:$1/$2" | jq -r .storePath
}

added_lines() {
  git diff --no-index -U0 "$1" "$2" | grep '^+' | grep -v '^+++' | cut -c2- || true
}

capped() {
  awk -v max="$max_lines" 'NR <= max { print } END { if (NR > max) print "… " NR - max " more lines, cut off here." }'
}

section() {
  local title="$1" body="$2" fence="$3"
  if [ -z "$body" ]; then
    printf '**%s**: nothing new.\n\n' "$title"
    return
  fi
  printf '<details>\n<summary><b>%s</b> (%s lines)</summary>\n\n~~~~%s\n%s\n~~~~\n\n</details>\n\n' \
    "$title" "$(wc -l <<< "$body")" "$fence" "$(capped <<< "$body")"
}

home_manager_news() {
  local old="$1" new="$2" file condition
  git diff --no-index --name-only --diff-filter=A "$old/modules/misc/news" "$new/modules/misc/news" 2> /dev/null \
    | { grep '\.nix$' || true; } | sort | while read -r file; do
    condition="$(sed -n 's/^ *condition = \(.*\);$/\1/p' "$file")"
    printf '## %s' "${file#"$new/modules/misc/news/"}"
    if [ -n "$condition" ] && [ "$condition" != true ]; then printf ' (only when %s)' "$condition"; fi
    printf '\n'
    awk "/message = ''/ { on = 1; next } /^ *'';/ { on = 0 } on" "$file" | sed 's/^    //'
    printf '\n'
  done
}

for input in nixpkgs home-manager nix-darwin omniwm; do
  was="$(rev "$old_lock" "$input")"
  now="$(rev "$new_lock" "$input")"
  if [ -z "$was" ] || [ "$was" = "$now" ]; then
    printf '**%s** did not move.\n\n' "$input"
    continue
  fi

  repo="$(source_of "$input")"
  old="$(fetch "$repo" "$was")"
  new="$(fetch "$repo" "$now")"

  case "$input" in
    nixpkgs)
      section "nixpkgs release notes" "$(
        added_lines "$old/doc/release-notes" "$new/doc/release-notes"
        added_lines "$old/nixos/doc/manual/release-notes" "$new/nixos/doc/manual/release-notes"
      )" markdown
      ;;
    home-manager)
      section "home-manager news" "$(home_manager_news "$old" "$new")" markdown
      ;;
    nix-darwin)
      section "nix-darwin changelog" "$(added_lines "$old/CHANGELOG" "$new/CHANGELOG")" markdown
      ;;
    omniwm)
      section "omniwm diff, to audit" "$(
        for path in nix scripts settings-defaults.toml; do
          git diff --no-index "$old/$path" "$new/$path" 2> /dev/null | sed "s|$old/||g; s|$new/||g" || true
        done
      )" diff
      ;;
  esac
done
