# caboodle

Every machine Shane runs, in one repo: PVE and Cube and their Incus
containers, Hetzner and Cloudflare, plus the desktop, the Deck, the MacBook
and the Mac mini. Read `README.md` for how it fits together.

## Making a change

- **Build:** to check a change, build here, on Shane's desktop, and only
  through `scripts/quietly.sh`: `scripts/quietly.sh colmena build --on
  <host>`. The wrapper runs one at a time, at idle priority, capped at 20
  GB, so a build never gets in the way of whatever Shane is doing on the
  machine, and a hook blocks the bare commands. A whole-hive evaluation is
  about 15 GB and a few minutes, so build the host you changed, not the
  hive. The local gate is `scripts/check.sh`. Flakes ignore untracked
  files, so `git add` new files first. Nix code reads for itself, with no
  comments.
- **Deploy:** a merge to `main` deploys the guests from the runner, through
  `.github/workflows/deploy.yml`, dns2 after dns1. The desktop is the
  fallback: `scripts/deploy.sh <host>` builds a host here and applies it over
  SSH, and with no arguments it applies every server. Only the desktop applies
  the runner and the mini, which builds on itself. PVE, Cube, the desktop, the
  Deck and the MacBook are switched by hand, each per its
  doc under `docs/`. `scripts/terraform.sh` plans Terraform with the tokens
  agenix holds, and `scripts/terraform.sh apply` applies that plan.
- **Pull request:** land every change through a pull request on GitHub
  (`origin`, `shaneplunkett/caboodle`). Commit on a branch and file it with
  the `pr` skill and `gh`, assigned to Shane for review. Done is a green
  check, plus the `Plan:` line from `scripts/terraform.sh` in the body when
  `terraform/` changed. Rebase onto `origin/main` before filing.
- **Merge:** Shane merges, except Renovate's Sunday pull requests (every
  dependency in one, the lock file in the other) and the `ai-skills` bumps,
  which merge themselves once the check passes. Merging deploys, unless only
  `docs/` changed, so choosing when to merge is choosing when it lands. The
  mini, and `terraform/` with `scripts/terraform.sh apply`, go from the
  desktop when Shane asks. A failed deploy is a red cross on the merge commit,
  and rollback is a revert pull request.
- **CI:** GitHub's runners run `scripts/check.sh` and nothing else.
  `.github/workflows/` calls the check workflow in `shaneplunkett/workflows`,
  pinned to a tag that Renovate moves, and `main` requires that check. Nothing
  on a pull request builds or deploys. `docs/adr/0005` says why,
  `docs/pve/runner.md` covers the deploy job, and `docs/github` covers the
  rest of GitHub.

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
