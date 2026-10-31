# Mirror

Incus guest on PVE holding a bare clone of every repo on Shane's GitHub
account, so losing GitHub costs no history. The service is
`modules/services/mirror`. There's no web UI, no git server and nothing to
sign into. Recovery is `git clone` from the folder.

## How it works

`/mnt/user/mirror` on PVE's pool is bind-mounted into the guest at
`/var/lib/mirror`, with one `<repo>.git` per repo. `mirror.timer` runs
`mirror.service` hourly, which:

1. Signs a JWT with the GitHub App's key (`github-app-client-id` and
   `github-app-private-key`, the same App as everything else, in the
   [builder doc](builder.md#github-app-and-inputs-token)) and swaps it for
   an hour-long installation token.
2. Lists the installation's repositories. The App is installed on every
   repo on the account, so that's all of them, private ones included.
3. `git clone --mirror`s any repo it hasn't seen, and runs
   `git remote update --prune` in the rest.

The token goes to git as an `Authorization` header in the environment, so
it never lands in a repo's config or on the command line. A repo that fails
doesn't stop the others; the unit fails at the end and
`mirror.service` is in the guest's monitored units, so the failure alerts.

`journalctl -u mirror` shows each run, and `systemctl start mirror` runs one
now.

## Why it's like this

- **Bare clones on a timer, not a forge.** A warm Forgejo kept as a pull
  mirror is a UI nobody opens with all the upkeep of one
  ([ADR 0003](../adr/0003-github-with-hosted-runners-and-no-builder.md)).
  Soft Serve was archived in October 2026, and gickup refreshes without
  pruning
  ([research](../research/2026-10-31-nix-ci-on-github-hosted-runners.md#git-mirror)).
- **On the pool, not the guest's disk.** The mirror outlives the guest, and
  a rebuilt guest picks it up where it left off.
- **The App, not a personal token.** Its tokens last an hour, and it already
  reaches every repo.

## Restoring

From the guest, any repo clones straight from the folder:

```sh
git clone /var/lib/mirror/caboodle.git
```

To give a repo back to a new forge, push everything the mirror holds:

```sh
git -C /var/lib/mirror/caboodle.git push --mirror <new remote>
```

## Backups

`/var/lib/mirror` is in `homelab.backup.paths`, so restic sends it to the
Storage Box and R2 like any guest's state
([hetzner](../hetzner/README.md)). That's the one path under the pool that
gets backed up: the module refuses `/mnt` paths, but inside the guest the
mount sits at `/var/lib/mirror`, and restic's `--one-file-system` still
crosses into a mount it's handed as a path. The mirror is a gigabyte or so,
nothing like the media shares the rule is there for.

A restore drill for one repo, on the guest:

```sh
restic-homelab restore latest --target /tmp/drill --include /var/lib/mirror/claws.git
git -c safe.directory='*' clone /tmp/drill/var/lib/mirror/claws.git /tmp/drill/claws
rm -rf /tmp/drill
```

The fetch takes restic's lock, `/run/lock/restic`, so a backup never reads
a repo halfway through a fetch. restic walks `objects/` before `refs/`, so
a fetch landing between the two would leave refs pointing at objects the
snapshot never got.

## The folder on PVE

`mirror-pool` on PVE makes `/mnt/user/mirror` before Incus starts, owned by
the guest's `mirror` user as PVE sees it. Guests are unprivileged with
Incus's default idmap, so guest uid `n` is `1000000 + n` on PVE.
`modules/services/mirror/pool.nix` reads the uid and gid from the guest's
config, so they're written once.

The folder isn't one of the NAS's shares, so nothing serves it over SMB or
NFS, and with mode 0700 only the guest reads it. `mirror` isn't in the
mover's list, so it stays on the cache SSD that `/mnt/user` fills first.

## The Forgejo dump

Forgejo's issues, pull requests, comments and reviews don't move to GitHub,
so `tools/forgejo-dump.sh` saves them as JSON before the forge goes. It
runs from the dev shell with rbw unlocked, and writes a README into the
dump saying what it is and when it was taken. The dump lives in the mirror's
folder so restic keeps it too:

```sh
tools/forgejo-dump.sh /tmp/forgejo
tar -C /tmp -cf - forgejo | ssh root@mirror \
  'rm -rf /var/lib/mirror/forgejo && tar -C /var/lib/mirror -xf - \
   && chown -R mirror:mirror /var/lib/mirror/forgejo'
```

Take it again at cutover, after the last pull request merges on the forge,
so the dump is the forge's final state.

## Gotchas

- **A repo GitHub doesn't have isn't mirrored.** The list comes from the
  App's installation, so a repo that only lives on the forge needs pushing
  to GitHub first.
- **Renamed or deleted repos stay.** A rename clones fresh under the new
  name, and the old folder stops updating. Delete it by hand if it's not
  wanted.
- **GitHub's pull request refs come along.** `--mirror` fetches
  `refs/pull/*` too, so each pull request's head survives even after its
  branch is gone.
- **A half-finished clone is `<repo>.git.partial`.** A clone goes there
  first and moves into place when it completes, so a failed one is retried
  from scratch on the next run instead of being treated as a mirror.
- **Root trusts the folder by config.** The repos belong to `mirror`, and
  git refuses to read a repo another user owns. The module sets
  `safe.directory` to `/var/lib/mirror/*` system-wide, so root clones from
  the folder as is. A restored copy elsewhere keeps the `mirror` owner, hence
  the `-c safe.directory='*'` in the drill.
- **No LFS.** `git clone --mirror` doesn't fetch LFS objects. No repo on the
  account used LFS in October 2026; one that starts needs `git lfs fetch
  --all` added.
