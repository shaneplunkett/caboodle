# Brain

NixOS LXC on PVE running the Vex brain (the memory server behind the `vex`
CLI) and its PostgreSQL. The container is `module "brain"` in
`terraform/pve-brain.tf`, and the service is `modules/services/vex-brain`.

## How it runs

The brain isn't packaged for Nix. Its source comes in as the `vex-brain` flake
input (the private repo over SSH, `flake = false`), and the service runs it
from the store as an ordinary Python app:

- Before each start, `uv sync --frozen` builds a venv in
  `/var/lib/vex-brain/venv` from the repo's `uv.lock`, against nixpkgs'
  `python312`. It's a no-op when nothing changed, so restarts don't need the
  network. A new Python store path wipes and rebuilds the venv.
- The prebuilt manylinux wheels work on NixOS as they are, so there's no
  nix-ld or `LD_LIBRARY_PATH`.
- The app binds to `127.0.0.1:8000` and talks to Postgres over the Unix socket
  with peer auth, so it has no database password.
- The secrets (OpenAI key, Honeycomb settings) are the `vex-brain` env file.

## Deploying a new version

The weekly flake update moves the `vex-brain` input. For a new version
sooner, run it from the Actions tab, or `nix flake update vex-brain` on a
branch, and merging deploys it.

The app runs its migrations on startup. If the update brings new files in
`app/migrations/`, take a backup first with
`ssh root@brain systemctl start restic-backups-homelab`, because migrations
only run forward.

The CLI, skills and Macs are deployed separately; see the vex-brain repo's
`docs/runbooks/deploy.md`.

## Cloudflare

`vex.shaneplunkett.dev` reaches the brain through the `brain` tunnel and the
`vex` Access app, which only lets the CLI's service token through. Both are
in Terraform (`terraform/cloudflare-tunnel.tf`), so the ingress changes by
pull request. It points at `http://vex-brain:8000`, the old Docker container
name, so the host maps `vex-brain` to `127.0.0.1`.

## Backups and restores

The backup's `prepare` step takes a `pg_dump` to `/var/backup/vex-brain`,
and restic backs that up rather than the live database. The dump is
uncompressed (`-Z0`) so restic can dedupe it between days. Every Saturday,
`vex-brain-restore-drill` restores the latest dump into a scratch database,
checks it has conversations and entities, and drops it. An alert fires if the
drill hasn't passed in 9 days.

`/var/lib/vex-brain-archive` is backed up too. It's the frozen mirror of
Claude Code session files from the old host, and for many rotated sessions
it's the only copy left. Nothing writes to it, and `source.sha256` and
`destination.sha256` beside it are the manifests from when it was copied.

To restore, put a dump on the host and run `vex-brain-restore <file>`. It
stops the brain, recreates the database with its extensions, restores the
dump as `vex_brain`, and starts the brain again:

```sh
restic-homelab restore latest --target /root/restore --include /var/backup/vex-brain
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
