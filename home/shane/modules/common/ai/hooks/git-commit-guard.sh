#!/usr/bin/env bash
# PreToolUse guard shared by Codex and Claude Code.
#
# It does not replace repository hooks. It prevents agents from bypassing them
# and blocks commits in repos that declare pre-commit config but have no active
# Git pre-commit hook installed.

set -euo pipefail

mode="${1:-codex}"
payload="$(cat || true)"

command=$(
  jq -r '
    if (.tool_input.cmd? | type) == "string" then
      .tool_input.cmd
    elif (.tool_input.command? | type) == "string" then
      .tool_input.command
    elif (.tool_input | type) == "string" then
      .tool_input
    else
      ""
    end
  ' <<<"$payload" 2>/dev/null || true
)

[ -n "$command" ] || exit 0

flat_command="$(printf '%s' "$command" | tr '\n' ' ')"

if ! grep -Eq '(^|[;&|[:space:]])git([[:space:]][^;&|]*)?[[:space:]]commit([[:space:]]|$)' <<<"$flat_command"; then
  exit 0
fi

reason=""

if grep -Eq '(^|[[:space:]])--no-verify([[:space:]]|$)|(^|[[:space:]])-[^-[:space:]]*n[^[:space:]]*([[:space:]]|$)' <<<"$flat_command"; then
  reason="Blocked git commit hook bypass: do not use --no-verify/-n. Fix the hook findings, or ask Shane explicitly before bypassing repo validations."
fi

if [ -z "$reason" ] && grep -Eq '(^|[[:space:];])(SKIP=|HUSKY=0|HUSKY_SKIP_HOOKS=1|LEFTHOOK=0|LEFTHOOK_SKIP=1|NO_VERIFY=1)' <<<"$flat_command"; then
  reason="Blocked git commit hook bypass: hook-disabling environment variables are not allowed for agent commits. Let the repo hooks run and fix what they report."
fi

if [ -z "$reason" ] && grep -Eq 'core\.hooksPath[[:space:]]*=[[:space:]]*($|/dev/null|NUL|none)' <<<"$flat_command"; then
  reason="Blocked git commit hook bypass: core.hooksPath cannot be disabled for agent commits. Let the repo hooks run and fix what they report."
fi

if [ -z "$reason" ]; then
  git_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"

  if [ -n "$git_root" ]; then
    declared_hook_source=""
    hooks_dir="$(git config --path core.hooksPath 2>/dev/null || true)"

    if [ -f "$git_root/.pre-commit-config.yaml" ] || [ -f "$git_root/.pre-commit-config.yml" ]; then
      declared_hook_source="pre-commit config"
    elif [ -f "$git_root/.husky/pre-commit" ]; then
      declared_hook_source="Husky pre-commit hook"
    elif [ -f "$git_root/lefthook.yml" ] || [ -f "$git_root/lefthook.yaml" ] || [ -f "$git_root/.lefthook/pre-commit" ]; then
      declared_hook_source="Lefthook config"
    elif [ -n "$hooks_dir" ]; then
      declared_hook_source="core.hooksPath"
    fi

    if [ -n "$hooks_dir" ]; then
      case "$hooks_dir" in
        /*) hook_path="$hooks_dir/pre-commit" ;;
        *) hook_path="$git_root/$hooks_dir/pre-commit" ;;
      esac
    else
      hook_path="$(git rev-parse --path-format=absolute --git-path hooks/pre-commit 2>/dev/null || git rev-parse --git-path hooks/pre-commit 2>/dev/null || true)"
      if [ -n "$hook_path" ] && [ "${hook_path#/}" = "$hook_path" ]; then
        hook_path="$git_root/$hook_path"
      fi
    fi

    if [ -n "$declared_hook_source" ] && { [ -z "$hook_path" ] || [ ! -e "$hook_path" ]; }; then
      reason="Repo declares $declared_hook_source, but the Git pre-commit hook is not installed. Run the repo pre-commit checks or install hooks before committing."
    elif [ -n "$hook_path" ] && [ -e "$hook_path" ] && [ ! -x "$hook_path" ]; then
      reason="A Git pre-commit hook exists at $hook_path, but it is not executable. Fix the hook installation before committing."
    fi
  fi
fi

[ -n "$reason" ] || exit 0

case "$mode" in
  claude)
    jq -n --arg reason "$reason" '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: $reason
      },
      systemMessage: $reason
    }'
    ;;
  codex)
    jq -n --arg reason "$reason" '{
      decision: "block",
      reason: $reason,
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        additionalContext: $reason
      }
    }'
    ;;
  *)
    printf '%s\n' "$reason" >&2
    exit 2
    ;;
esac
