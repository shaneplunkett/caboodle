# caboodle

Every machine Shane runs, in one repo: the Proxmox cluster, Hetzner and
Cloudflare, plus the desktop, the MacBook and the Mac mini. Read `README.md`
for how it fits together.

## Making a change

- **Build:** CI builds the hosts a pull request changes on the builder, so
  nothing evaluates or builds on Shane's desktop: a full evaluation of the
  hive takes gigabytes, and a few at once take the machine down. The local
  gate is `scripts/check.sh`. For one host's answer before filing,
  `nix build --store ssh-ng://root@builder .#hydraJobs.<host>` builds it on
  the builder and leaves nothing here. To run a result here, fetch it
  through the cache, `nix copy --from https://cache.shaneplunkett.com
  <path>`, since the builder signs nothing itself and a copy over SSH is
  refused as unsigned. `docs/pve/builder.md` has the by-hand gotchas.
  Flakes ignore untracked files, so `git add` new files first. Nix code
  reads for itself, with no comments.
- **Pull request:** land every change through a pull request on the forge
  (`origin`; GitHub is a mirror of it). Commit on a branch and file it with
  the `pr` skill, which opens it and assigns it to Shane for review. Done is a
  green build check, the derivation diff comment, plus a Terraform plan
  comment showing what you expect when `terraform/` changed.
- **Merge:** Shane merges, except the `ai-skills` bumps that merge
  themselves once every host builds (`docs/pve/builder.md`). Merging applies
  Terraform and deploys every host but the desktop and the MacBook. CI builds
  those two, and Shane switches each by hand per its doc under `docs/`.
- **Derivation diff:** CI works out which hosts a pull request changes,
  against its merge base, and posts them as a `forge-bot` comment it edits on
  each push. Shane reads it herself, so the pull request body doesn't list
  hosts. Rebase onto `origin/main` before filing anyway, so the build check
  runs against what would merge. A package built from `lib.cleanSource ./.`
  changes with any file in its folder, its README included, so a docs edit
  there shows up as that package's hosts.
- **CI:** the files in `.forgejo/workflows/` are callers of `shane/workflows`
  (build, check, flake update, checkout), pinned to a tag. Change CI behaviour
  there, following its `AGENTS.md`, and Renovate moves the pins here. Steps
  check out with `https://git.shaneplunkett.com/shane/workflows/checkout@<tag>`.

## Checks

`scripts/check.sh` is the gate: pre-commit, CI and the agents' Stop hook all
run it. An edit hook also formats and lints each Nix, Terraform, Python, JS
or TS file straight after you change it. Fix what the gate reports, without
suppression comments. If a rule is wrong for the case, say so and propose a
change to its config.

## Secrets

Pipe values from rbw straight into `agenix -e`. Show a secret or token only
by its name, length or recipient count.

## Services

- **Sign-in:** every web app with a frontend that a change adds signs in
  through Pocket ID, with its own OIDC login or, if it has none, behind the
  oauth2-proxy gate. A backend whose clients bring their own credentials,
  like BlueBubbles, stays ungated, since its clients can't sign in.
  `docs/pve/auth.md` covers both. An OIDC client is declared with
  `homelab.oidcClients` in the app's module, and merging creates it in
  Pocket ID. Adding Shane to the app's group is the one step left in Pocket
  ID's UI. The app is done when her passkey gets her in.
- **Monitoring:** the Grafana MCP is read-only. Use it to investigate
  (Prometheus and Loki), then report. Remediation goes through a pull
  request, never on the MCP's findings alone.
- **Cloudflare:** reach for the `cloudflare` MCP server first, then `cf` from
  the dev shell. Wrangler is only for Workers and Pages. See
  `docs/cloudflare/README.md`.

## Docs

Docs hold the how, the why and the gotchas. State (IPs, versions, sizes,
what's deployed where) lives in the code, and if the code explains it, it
doesn't need a doc.

## Tickets

Linear label `repo:caboodle`, in the Engineering team.
