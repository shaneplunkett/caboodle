---
name: flake-update
description: Triage the changelogs behind a flake input bump and report what touches this config. Use when reviewing a flake.lock update pull request or a local `nix flake update`.
---

# Flake update

`nix flake update` only prints lock hashes. home-manager's news never
displays when it runs as a NixOS or nix-darwin module, so behaviour
changes land silently. This skill turns the upstream changelogs for a
bump into a short **impact list** for Shane.

## 1. Gather

The weekly update pull request (`update/flake-lock`, opened by
forge-bot) already carries the raw material: new evaluation warnings per
host, package changes per host, and a Changelogs section produced by
`scripts/flake-update-notes.sh`. Read its body with `tea pr <index>`.

For a bump made locally, produce the same material yourself:

- Changelogs: `scripts/flake-update-notes.sh <(git show HEAD:flake.lock) flake.lock`.
- Warnings: build every host on the old and new lock with
  `--option eval-cache false` (a cached eval prints no warnings) and keep
  the `evaluation warning:` lines that only the new lock prints. Trace one
  to its source with `--option abort-on-warn true --show-trace`.

Changelogs cover nixpkgs, home-manager, nix-darwin and omniwm. Every other
moved input is covered by the builds alone; name them in the report so
that limit is visible.

`llm-agents` and the Homebrew taps are pinned in `flake.nix`, so Renovate
moves them in its own pull requests and merges each once it builds. They
never appear in the weekly one.

Done when you hold the warnings and every changelog section, expanded.
A section cut off at its line cap gets re-run locally in full.

## 2. Read

Read every entry. home-manager entries carry their `condition`, so a
darwin-only entry can only hit the Macs.

**omniwm** is a one-person flake whose activation script runs on every
switch and whose bumps land on main without review, so audit its diff
rather than summarise it: new commands, network access, writes outside
`~/.config/omniwm/`, or a package URL off `github.com/OmniNull/OmniWM`.

**vex-brain** runs its migrations on startup, and merging deploys it, so
when it moved, list the files the bump brings:
`tea api /repos/shane/vex-brain/compare/<old>...<new> | jq -r '.files[].filename'`.
Anything under `app/migrations/` is a hit whose move is the backup in
`docs/pve/brain.md`, taken before the merge.

Done when every entry has been read, the omniwm diff audited and any
vex-brain migrations listed.

## 3. Triage

Classify each item as **hits**, **opt-in**, or **miss**:

- **Hits**: names an option, module, or package this repo sets or
  installs, or is a new evaluation warning. Grep the repo for it; a hit
  needs the file that uses it.
- **Opt-in**: a new default gated on `home.stateVersion` or
  `system.stateVersion`. The workstations' state versions are old, so these
  defaults never arrive on their own (home-manager's `copyApps` sat
  unnoticed this way). Read the current values from the host configs
  before judging.
- **Miss**: everything else.

Done when every item from step 2 has a class.

## 4. Report

Give Shane the hits and opt-ins only: one line each saying what changed,
where it touches the config, and the suggested move. Name the count of
misses in one closing line, and any omniwm audit finding. When nothing
hits, say so in one sentence. Make no config changes until she picks what
to act on.
