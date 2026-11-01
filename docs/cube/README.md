# Cube

## Summary

NixOS host that runs the Incus guests that need Quick Sync or should stay
off PVE: plex, arr and dlna beside it, monitoring and dns2 so they outlive
PVE, and photos, paper and music. Its config is `hosts/cube`. Incus, and
looking after a guest, is in [incus](../../modules/services/incus/README.md).

Per-service docs:

- [arr.md](arr.md)
- [dispatcharr.md](dispatcharr.md)
- [plex.md](plex.md)
- [photos.md](photos.md)
- [paper.md](paper.md)
- [music.md](music.md)

## Deploying

Nothing deploys Cube, since a bad switch takes every guest on it down. Switch it by hand the way PVE is
([pve](../pve/README.md#deploying)), with the rollback armed for anything
that touches `br0` or the uplink. Its keyboard is the JetKVM.

## NAS storage

Cube mounts PVE's Media and Programs shares over NFS at `/mnt/media` and
`/mnt/programs`, and passes them to plex, arr, music and dlna as Incus
`disk` devices. The mounts are `soft`, so a dead PVE gives errors rather than
processes stuck in D state. Incus waits for both mounts to finish trying,
for up to 30 seconds each, but they're `nofail`: if PVE is down at boot,
Incus starts anyway so dns2 and monitoring come up, and plex, arr, music
and dlna see an empty folder. The first gotcha below fixes that.

Immich's library stays on photos' own disk, on purpose: restic backs up
guest disks and never the NAS, so a library on the NAS would have no offsite
copy.

## Gotchas

- **A share that was down when Cube booted stays empty**, and plex, arr,
  music and dlna see an empty folder. Mount it, then restart those guests so
  they bind the real share:

  ```sh
  ssh root@<cube> 'systemctl restart mnt-media.mount mnt-programs.mount && incus restart plex arr music dlna'
  ```

  If a mount says `Operation not permitted`, the NAS isn't exporting yet,
  usually because its pool hasn't mounted.
- **The network port is gigabit.** Copying a guest's state off or back on
  runs at about 110 MB/s, so photos' library alone takes about 17 minutes.
- **The JetKVM's keyboard misses the boot menu.** To boot something else
  once, set it from the running system with `efibootmgr --bootnext`.
