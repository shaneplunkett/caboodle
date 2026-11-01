# Mirror

Incus guest on PVE holding a bare clone of every repo on Shane's GitHub
account, so losing GitHub costs no history. The service is
`modules/services/mirror`. There's no web UI, no git server and nothing to
sign into. Recovery is `git clone` from the folder.

`mirror.timer` runs hourly. It mints a token from the GitHub App
([builder](builder.md#github-app-and-inputs-token)), lists the repos the
App is installed on, which is all of them, then `git clone --mirror`s the
new ones and `git remote update --prune`s the rest into `/var/lib/mirror`.
A repo that fails doesn't stop the others; the unit fails at the end. `journalctl -u mirror` shows each run, and `systemctl start mirror`
runs one now.

## Why it's like this

- **Bare clones on a timer, not a forge.** A warm Forgejo kept as a pull
  mirror is all the upkeep of a forge for a UI nobody opens. Soft Serve was
  archived in October 2026, and gickup refreshes without pruning.
- **On the pool, not the guest's disk.** `/mnt/user/mirror` on PVE is
  bind-mounted at `/var/lib/mirror`, so the mirror outlives the guest and a
  rebuilt guest picks up where it left off.
- **The App, not a personal token.** Its tokens last an hour, and it already
  reaches every repo.

## Restoring

```sh
git clone /var/lib/mirror/caboodle.git
git -C /var/lib/mirror/caboodle.git push --mirror <new remote>
```

The first clones a repo on the guest; the second gives everything the
mirror holds to a new forge.

## Backups

`/var/lib/mirror` is in `homelab.backup.paths`, so restic sends it offsite
([hetzner](../hetzner/README.md)). It's the one path under the pool that
gets backed up: the module refuses `/mnt` paths, but inside the guest the
mount is `/var/lib/mirror`, and restic's `--one-file-system` still crosses
into a mount it's handed as a path. A restore drill for one repo, on the
guest:

```sh
restic-homelab restore latest --target /tmp/drill --include /var/lib/mirror/claws.git
git -c safe.directory='*' clone /tmp/drill/var/lib/mirror/claws.git /tmp/drill/claws
rm -rf /tmp/drill
```

The fetch takes restic's lock, `/run/lock/restic`. restic walks `objects/`
before `refs/`, so a fetch landing between the two would leave refs
pointing at objects the snapshot never got.

## The Forgejo dump

Forgejo's issues, pull requests, comments and reviews don't move to GitHub,
so `tools/forgejo-dump.sh` saves them as JSON. It runs from the dev shell
with rbw unlocked, and the dump lives in the mirror's folder so restic
keeps it too. Take it again at cutover, after the last pull request merges
on the forge:

```sh
tools/forgejo-dump.sh /tmp/forgejo
tar -C /tmp -cf - forgejo | ssh root@mirror \
  'rm -rf /var/lib/mirror/forgejo && tar -C /var/lib/mirror -xf - \
   && chown -R mirror:mirror /var/lib/mirror/forgejo'
```

## Gotchas

- **A repo GitHub doesn't have isn't mirrored.** A repo that only lives on
  the forge needs pushing to GitHub first.
- **Renamed or deleted repos stay.** A rename clones fresh under the new
  name, and the old folder stops updating. Delete it by hand.
- **GitHub's pull request refs come along.** `--mirror` fetches
  `refs/pull/*`, so each pull request's head survives its branch.
- **A half-finished clone is `<repo>.git.partial`**, moved into place when
  it completes, so a failed one is retried from scratch.
- **The folder's owner is the guest's `mirror` user as PVE sees it**, uid
  `1000000 + n` under Incus's default idmap. `mirror-pool` on PVE makes it
  before Incus starts, reading the uid from the guest's config. It isn't a
  NAS share and isn't in the mover's list, so it stays on the cache SSD.
- **Root trusts the folder by config.** git refuses a repo another user
  owns, so the module sets `safe.directory` to `/var/lib/mirror/*`. A
  restored copy elsewhere keeps the `mirror` owner, hence the
  `-c safe.directory='*'` in the drill.
- **No LFS.** `git clone --mirror` doesn't fetch LFS objects. A repo that
  starts using LFS needs `git lfs fetch --all` added.
