---
name: flake-update
description: Triage the changelogs behind a flake input bump and report what touches this config. Use when reviewing a flake.lock update pull request, Renovate's weekly lock file maintenance, or a local `nix flake update`.
---

# Flake update

`nix flake update` only prints lock hashes. home-manager's news never
displays when it runs as a NixOS or nix-darwin module, so behaviour
changes land silently. This skill turns the upstream changelogs for a
bump into a short **impact list** for Shane.

## 1. Gather

Renovate's lock file maintenance pull request opens on Saturday night
(`docs/github/README.md`), lists only what moved, and merges itself once
the check passes. The check builds nothing, so by the time Shane asks it
has usually landed and the merge has deployed the servers. Find it with
`gh pr list --search "lock file maintenance" --state all` and read it
with `gh pr view <number>`. Then gather the rest yourself, the same as for
a bump made locally. The old lock is `main` before the bump and the new
one is after it; write both to files in the scratchpad:

- Merged: `git show <merge>^:flake.lock` and `git show <merge>:flake.lock`.
- Open: `git show origin/main:flake.lock` and the branch's `flake.lock`.
- Local: `git show HEAD:flake.lock` and the working tree's.

Then:

- Changelogs: `scripts/flake-update-notes.sh <old lock> <new lock>`. It
  prefetches every moved tree, so a nixpkgs bump downloads a few hundred
  megabytes the first time.
- Warnings: build the hive on the old and new lock through
  `scripts/quietly.sh colmena build --on <host> --option eval-cache false`
  (a cached eval prints no warnings) and keep the `evaluation warning:`
  lines that only the new lock prints. Trace one to its source with
  `--option abort-on-warn true --show-trace`.

Changelogs cover nixpkgs, home-manager, nix-darwin and omniwm. Every other
moved input is covered by the builds alone; name them in the report so
that limit is visible.

`llm-agents` and the Homebrew taps are pinned in `flake.nix`, so Renovate
moves them in the dependency pull request that opens beside the lock one,
and they never appear in the lock one.

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
`gh api repos/shaneplunkett/vex-brain/compare/<old>...<new> --jq '.files[].filename'`.
Anything under `app/migrations/` is a hit. The weekly bump has merged
itself by the time it's triaged, so those migrations have already run:
say so, and check the brain is up. For a bump made by hand, the backup in
`docs/pve/brain.md` comes before the merge.

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
