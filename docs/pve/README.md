# PVE

## Summary

NixOS host that runs the Incus guests and is the NAS. Its config is
`hosts/pve`. How Incus is set up, and how to look after a guest, is in
[incus](../../modules/services/incus/README.md).

Per-service docs:

- [auth.md](auth.md)
- [brain.md](brain.md)
- [home.md](home.md)
- [mirror.md](mirror.md)
- [recipes.md](recipes.md)
- [rss.md](rss.md)

## Deploying

Nothing deploys PVE. It's the hypervisor and the NAS, so a bad switch takes
every guest down with it. Shane switches it by hand.

Build it on the desktop, push the closure to PVE over SSH, and switch:

```sh
path=$(scripts/quietly.sh nix build --no-link --print-out-paths .#hydraJobs.pve)
nix copy --to ssh://root@<pve> "$path"
ssh root@<pve> "nix-env -p /nix/var/nix/profiles/system --set $path \
  && $path/bin/switch-to-configuration switch"
```

`<pve>` is its LAN address. Nothing in the path depends on a guest, so this
works with PVE's networking half up.

- **SSH in over the LAN, not Tailscale.** A switch can restart tailscaled
  and drop the session halfway.

## Changing the network

A mistake in `br0` or the uplink cuts PVE off the LAN, and SSH with it, so
the only way back is a keyboard. Arm a rollback before trying the new
system, and only switch for good once it works. On PVE, with `$path` the
new system already fetched:

```sh
old=$(readlink -f /run/current-system)
systemd-run --on-active=240 --unit=rollback $old/bin/switch-to-configuration test
$path/bin/switch-to-configuration test
```

From a new SSH session, check PVE and a guest or two still answer. Then
cancel the rollback and switch:

```sh
systemctl stop rollback.timer
nix-env -p /nix/var/nix/profiles/system --set $path
$path/bin/switch-to-configuration switch
```

`test` leaves the boot entry alone, so if the timer doesn't save it, a
reboot still comes back on the old system.

## NAS

`modules/services/nas` mounts the old Unraid drives as they were, plain XFS
disks and a btrfs NVMe cache, and pools them with mergerfs under Unraid's
paths, so exports and the arr settings never changed. `/mnt/user` puts new
files on the cache first, and the nightly mover shifts what's sat there a
day onto the disks through `/mnt/user0`. There's no parity drive yet.

- **NFS over mergerfs needs `never-forget-nodes`, `inodecalc=path-hash`
  and a fixed `fsid` per export**, or clients get stale handles.
- **The exports wait for the pool.** If NFS or Samba started before
  mergerfs mounted, they'd export the empty directory underneath and
  clients would write onto the root disk, so both require `/mnt/user`.
- **A pool with a missing disk doesn't mount**, the way Unraid refused to
  start its array, so arr never sees files vanish.
- **Everything is owned by 99:100.** NFS squashes every client to it and
  Samba forces it, as Unraid did. The `nas` user holds uid 99.
- **The mover keeps hardlinks** by handing rsync the whole file list with
  `-H`. Moving files one at a time would split each torrent from its
  library copy and use the space twice.
- **The mover skips SQLite's `-wal`, `-shm` and `-journal` files.**
  Calibre-Web-Automated keeps its database open in `Media/library`, and
  moving the sidecars under an open database can corrupt it.
- **NFS clients' open files aren't visible here**, so the mover can't skip
  a file a client still has open.
