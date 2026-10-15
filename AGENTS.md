## Working in this repo

Read `README.md` for how the repo fits together.

- **Nix:** check changes with `colmena build --on <host>` and `git add` new
  files first (flakes ignore untracked files). Don't add comments to Nix code;
  it should read for itself.
- **Derivation diff:** every pull request names which hive nodes change and
  why. Compare `hydraJobs`' derivation paths between the base and your branch,
  each unpacked into a temp directory with `git archive` and evaluated as a
  `path:` flake, which also works inside a worktree:

  ```sh
  nix eval --json path:/tmp/dd/<side>#hydraJobs --apply 'js: builtins.mapAttrs (_: d: d.drvPath) js'
  ```

  A package built from `lib.cleanSource ./.` changes with any file in its
  folder, its README included. For one node,
  `nix path-info --derivation .#hydraJobs.<node>` hits the eval cache on a
  repeat run, and `nix eval` never does.
- **Checks:** `scripts/check.sh` is the one gate: nixfmt, statix and deadnix
  for Nix; `terraform fmt`, `validate` and tflint for Terraform; ruff's
  formatter and linter for Python; Biome for JavaScript and TypeScript. Hooks
  run it for you in Claude Code and Codex. Each edit is formatted and linted
  straight after, the Stop hook runs the whole check before you finish, and
  pre-commit runs it on every commit (`pre-commit install` once per clone).
  Fix what it reports, without suppression comments. If a rule is wrong for
  the case, say so and propose a change to `statix.toml`, `ruff.toml`,
  `biome.json` or `terraform/.tflint.hcl`.
- **Secrets:** pipe values from rbw straight into `agenix -e`, and never print
  a secret or token. Only show names, lengths or recipient counts.
- **Monitoring:** the Grafana MCP is read-only. Use it to investigate
  (Prometheus and Loki), then report. Never remediate on its findings alone.
- **Changes:** land every change through a pull request on the forge
  (`origin`; GitHub is a mirror of it). Commit on a branch and file it with
  the `file-pr` skill, which opens it as Vex and asks Shane to review. Done is
  a green build check, plus a Terraform plan comment showing what you expect
  when `terraform/` changed. Shane merges: merging applies Terraform and
  deploys every host but the desktop and the MacBook. CI builds those two,
  and Shane switches each by hand per its doc under `docs/`.
- **CI:** the files in `.forgejo/workflows/` are callers of `shane/workflows`
  (build check, flake update, checkout), pinned to a tag. Change CI behaviour
  there, following its `AGENTS.md`, and Renovate moves the pins here. Steps
  check out with `https://git.shaneplunkett.com/shane/workflows/checkout@<tag>`.
- **Sign-in:** every web app a change adds signs in through Pocket ID,
  with its own OIDC login or, if it has none, behind the oauth2-proxy gate.
  `docs/pve/auth.md` covers both. An OIDC client is declared with
  `homelab.oidcClients` in the app's module, and merging creates it in
  Pocket ID. Adding Shane to the app's group is the one step left in Pocket
  ID's UI. The app is done when her passkey gets her in.
- **Docs:** keep state out of them (IPs, versions, sizes, what's deployed
  where). If the code explains it, it doesn't need a doc. Docs hold the how,
  the why, and the gotchas.

## Agent skills

### Issue tracker

Issues and PRDs live in Linear (workspace `metrokitten`, team `SHA`), managed via the Linear MCP.
See `docs/agents/issue-tracker.md`.

### Triage labels

Use the default triage vocabulary.
See `docs/agents/triage-labels.md`.

### Domain docs

This is a single-context repo.
See `docs/agents/domain.md`.

## Cloudflare

Use the `cloudflare` MCP server first, then `cf` from the dev shell. Wrangler is only for Workers and Pages.
See `docs/cloudflare/README.md`.
