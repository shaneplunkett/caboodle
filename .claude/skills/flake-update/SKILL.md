---
name: flake-update
description: Write the release notes for a flake bump, Renovate's weekly one included, and triage what touches this config. Use when reviewing a flake.lock or dependency update, when Shane asks what changed or what's new after a bump, or for a local `nix flake update`.
---

# Flake update

`nix flake update` only prints lock hashes, a merged Renovate pull request
lists only what moved, and a green deploy only proves each host switched:
Norish 0.26 moved its OIDC callback and nobody could sign in to recipes
while every check stayed green. home-manager's news never displays when it
runs as a NixOS or nix-darwin module either. This skill turns a bump into
**release notes** for Shane: what changed on each machine, what's new in
the things she uses, and what broke or touches the config.

## 1. Gather

Renovate opens two pull requests on Saturday night
(`docs/github/README.md`), and both merge themselves once the check
passes, so by the time Shane asks they have usually landed and the merges
have deployed the servers. Find them with
`gh pr list --state merged --search "lock file maintenance"` and
`--search "Update all dependencies"`, and read each with `gh pr view`.
The dependency one carries the container images (the `docker` rows), the
pinned inputs (`llm-agents` and the Homebrew taps) and the Terraform
providers; none of those show in a lock diff or a closure diff, so note
them here. Then gather the rest yourself, the same as for a bump made
locally.

The old lock is `main` before the bump and the new one is after it; write
both to files in the scratchpad:

- Merged: `git show <merge>^:flake.lock` and `git show <merge>:flake.lock`.
- Open: `git show origin/main:flake.lock` and the branch's `flake.lock`.
- Local: `git show HEAD:flake.lock` and the working tree's.

Then:

- Changelogs: `scripts/flake-update-notes.sh <old lock> <new lock>`. It
  prefetches every moved tree, so a nixpkgs bump downloads a few hundred
  megabytes the first time.
- Per host: `scripts/release-diff.sh <merged-at> <host>...` with the
  `mergedAt` of the first pull request to land and every host in the hive.
  The hosts are the files under `hosts/`, where `dns.nix` is `dns1` and
  `dns2`. A deployed host diffs its own generations; a hand-switched one
  (PVE, Cube, the runner, the desktop, the Deck, the Macs) diffs what it
  runs against what `main` builds for it, so those lines are what Shane
  will get when she switches. A host that's asleep is skipped and named.
- Warnings: build the hive on the old and new lock through
  `scripts/quietly.sh colmena build --on <host> --option eval-cache false`
  (a cached eval prints no warnings) and keep the `evaluation warning:`
  lines that only the new lock prints. Trace one to its source with
  `--option abort-on-warn true --show-trace`.

Changelogs cover nixpkgs, home-manager, nix-darwin and omniwm. Everything
else is covered by the closure diffs and the builds; name any moved input
that none of those reach, so that limit is visible.

Done when you hold the warnings, every changelog section expanded, a diff
or a named skip for every host, and the dependency pull request's rows.

## 2. Read

Read every changelog entry. home-manager entries carry their `condition`,
so a darwin-only entry can only hit the Macs.

Then read upstream for everything in the closure diffs and the dependency
rows that Shane uses: the services under `modules/services`, the apps the
workstations install, and the agent CLIs. For each one that moved, read
its release notes between the two versions, `gh api repos/<owner>/<repo>/releases`
or the project's changelog, and keep two things: what's new that she'd
notice, and anything under a breaking or migration heading. A build bump
within one version (Plex) has nothing to read; say so. A breaking entry
that names a URL, a port, a path, a config key or a migration is the one
to chase, because nothing in the pipeline will.

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

Done when every changelog entry has been read, every moved app or service
Shane uses has its release notes read or its lack of them named, the
omniwm diff audited and any vex-brain migrations listed.

## 3. Triage

Classify each item as **broken**, **hits**, **opt-in**, or **miss**:

- **Broken**: a breaking entry whose subject this repo declares or that a
  deployed service now depends on. Prove it against the running system
  before calling it: ask the service and its counterpart directly (Pocket
  ID's authorize endpoint for a callback, the old and new path for a URL).
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

Write the release notes in the chat, in this order, one line per item,
versions in the lists rather than the prose:

1. **Heads up**: anything broken, with the proof and the one-line fix, then
   anything that breaks on a switch.
2. **Live on the servers**: what the deploy changed, grouped by what she'd
   recognise (Grafana, the Matter server, Plex), with what's new in plain
   words for the ones she uses. Name what didn't move that she might
   expect to (Home Assistant, Immich).
3. **Waiting for a switch**: the hand-switched hosts, one group each, the
   notable moves first.
4. **Config**: the hits and opt-ins, each saying what changed, where it
   touches the config, and the suggested move.

Close with the count of misses, any omniwm audit finding, and what wasn't
checked: the hosts that were asleep, the warnings step if it was skipped.
When nothing hits, say so in one sentence. Make no config changes until
she picks what to act on; a broken item gets offered as a pull request.
