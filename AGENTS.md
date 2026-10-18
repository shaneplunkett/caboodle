# caboodle

Every machine Shane runs, in one repo: the Proxmox cluster, Hetzner and
Cloudflare, plus the desktop, the MacBook and the Mac mini. Read `README.md`
for how it fits together.

## Making a change

- **Build:** check changes with `colmena build --on <host>`. Flakes ignore
  untracked files, so `git add` new files first. Nix code reads for itself,
  with no comments.
- **Pull request:** land every change through a pull request on the forge
  (`origin`; GitHub is a mirror of it). Commit on a branch and file it with
  the `pr` skill, which opens it and assigns it to Shane for review. Done is a
  green build check, plus a Terraform plan comment showing what you expect
  when `terraform/` changed.
- **Merge:** Shane merges, except the `ai-skills` bumps that merge
  themselves once every host builds (`docs/pve/builder.md`). Merging applies
  Terraform and deploys every host but the desktop and the MacBook. CI builds
  those two, and Shane switches each by hand per its doc under `docs/`.
- **Derivation diff:** every pull request names which hosts change and
  why. Fetch and rebase onto `origin/main` first: other agents' fetches move
  it under you, and a stale base counts their changes as yours. Then compare
  `hydraJobs`' derivation paths between `origin/main` and your branch,
  each unpacked into a temp directory with `git archive` and evaluated as a
  `path:` flake, which also works inside a worktree:

  ```sh
  nix eval --json path:/tmp/dd/<side>#hydraJobs --apply 'js: builtins.mapAttrs (_: d: d.drvPath) js'
  ```

  A package built from `lib.cleanSource ./.` changes with any file in its
  folder, its README included. For one host,
  `nix path-info --derivation .#hydraJobs.<host>` hits the eval cache on a
  repeat run, and `nix eval` never does.
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
