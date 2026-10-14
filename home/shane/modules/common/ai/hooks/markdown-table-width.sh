#!/usr/bin/env bash
# PostToolUse check shared by Codex and Claude Code.
#
# Markdown table rows can't wrap, so a row wider than the editor window breaks
# table rendering in Neovim. Hand wide rows straight back to the agent so the
# table is restructured in the same turn. Rows already committed at HEAD are
# left alone, so editing someone else's document doesn't demand a rewrite.

set -euo pipefail

max_width=100

payload="$(cat || true)"

cwd="$(jq -r '.cwd // empty' <<<"$payload" 2>/dev/null || true)"
[ -z "$cwd" ] || cd "$cwd" || exit 0

findings=""
while IFS= read -r file; do
  [ -f "$file" ] || continue

  committed="$(git -C "$(dirname "$file")" show "HEAD:./$(basename "$file")" 2>/dev/null || true)"

  # Width is measured roughly as rendered: link targets and inline markup are
  # concealed in the editor, so they don't count.
  rows="$(
    jq -Rrn --argjson max "$max_width" --arg committed "$committed" '
      ($committed | split("\n") | map({ key: ., value: true }) | from_entries) as $old
      | foreach inputs as $line ({ fence: false, n: 0 };
          .n += 1 | .width = 0
          | if ($line | test("^\\s*(```|~~~)")) then .fence |= not
            elif (.fence | not) and ($line | test("^\\s*\\|")) and ($old[$line] | not) then
              .width = ($line | gsub("\\]\\([^)]*\\)"; "") | gsub("[`*\\[]"; "") | length)
            else . end;
          select(.width > $max) | "  line \(.n): \(.width) columns")
    ' "$file" 2>/dev/null || true
  )"

  [ -z "$rows" ] || findings+="$file"$'\n'"$rows"$'\n'
done < <(hook-changed-files <<<"$payload" 2>/dev/null | grep -E '\.(md|mdx)$' | sort -u || true)

[ -n "$findings" ] || exit 0

reason="Markdown table rows wider than $max_width columns break table rendering in Shane's editor:

$findings
Keep table cells to a few words and move the prose into a list or paragraphs under the table, or replace the table with a list."

jq -n --arg reason "$reason" '{
  decision: "block",
  reason: $reason,
  hookSpecificOutput: { hookEventName: "PostToolUse", additionalContext: $reason }
}'
