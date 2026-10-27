# Brain

NixOS Incus container on PVE running the Vex brain (the memory server behind
the `vex` CLI) and its PostgreSQL. Its size is `homelab.guest` in
`flake.nix`, `terraform/incus.tf` makes it, and the service is
`modules/services/vex-brain`.

## How it runs

The brain isn't packaged for Nix. Its source is the `vex-brain` flake input,
the private repo on the forge, and the service runs it from the store as an
ordinary Python app in a uv venv. The prebuilt manylinux wheels work on NixOS
as they are, so it needs no nix-ld.

## Deploying a new version

The weekly flake update moves the `vex-brain` input. For a new version
sooner, run it from the Actions tab, or `nix flake update vex-brain` on a
branch, and merging deploys it.

The app runs its migrations on startup. If the update brings new files in
`app/migrations/`, take a backup first with
`ssh root@brain systemctl start restic-backups-homelab`, because migrations
only run forward.

The same bump ships the `vex` CLI and its `memory-save` skill to every
workstation: the mini on merge, the desktop and the MacBook when Shane
switches them. The vex-brain repo's `docs/runbooks/deploy.md` has the
steps and the rollback.

## Cloudflare

`vex.shaneplunkett.dev` reaches the brain through the `brain` tunnel and the
`vex` Access app, which only lets the CLI's service token through. Both are
in Terraform (`terraform/cloudflare-tunnel.tf`), so the ingress changes by
pull request. It points at `http://vex-brain:8000`, the old Docker container
name, so the host maps `vex-brain` to `127.0.0.1`.

## Backups and restores

`vex-brain-restore-drill` proves the latest dump restores, and alerts if it
stops passing.

`/var/lib/vex-brain-archive` is backed up too. It's the frozen mirror of
Claude Code session files from the old host, and for many rotated sessions
it's the only copy left. Nothing writes to it, and `source.sha256` and
`destination.sha256` beside it are the manifests from when it was copied.

To restore, put a dump on the host and run `vex-brain-restore <file>`.
The nightly backup overwrites the dump, so pick the snapshot by its time
from `restic-homelab snapshots` (times are UTC) rather than taking
`latest`:

```sh
restic-homelab restore <snapshot> --target /root/restore --include /var/backup/vex-brain
vex-brain-restore /root/restore/var/backup/vex-brain/vex_brain.dump
```

## Gotchas

- **Never run two connectors for the tunnel against different databases.**
  Cloudflare spreads requests across every connector, so two brains would
  each take half the writes.
- **The CLI keeps its sync watermarks on the client**
  (`~/.local/state/vex-sync-cc`, `vex-sync-codex`). Pointing `vex sync-cc` at
  a test brain marks those sessions as sent, so use `--state-file` with a
  throwaway path.
- **Restores skip the dump's `EXTENSION` entries.** `vector` isn't a trusted
  extension, so `vex-brain-restore` creates both extensions as `postgres` and
  restores everything else as `vex_brain`. The NixOS setup creates them the
  same way for a fresh database.
