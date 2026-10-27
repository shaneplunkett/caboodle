# Cube

## Summary

The one Proxmox node left, a cluster of one. Its guests are Proxmox LXCs
from `terraform/cube-*.tf` until they move to Incus, the way PVE's did
([incus](../../modules/services/incus/README.md#moving-a-guest-onto-incus)).

Per-service docs:

- [arr.md](arr.md)
- [dispatcharr.md](dispatcharr.md)
- [plex.md](plex.md)
- [photos.md](photos.md)
- [paper.md](paper.md)

## NAS storage

The NAS's NFS shares are Proxmox storage pools (`terraform/storage.tf`), so Proxmox owns the mount lifecycle, reconnection, and health. You can see them in the web UI under Storage.

LXCs don't mount NFS themselves. They bind-mount the host path `/mnt/pve/<storage id>` instead.

## Gotchas

- **The storage IDs still say `unraid-`.** Renaming one moves its mount
  path, which the containers' bind mounts would have to follow by hand.
- **Shares that were down when Cube mounted them stay empty**, and Plex,
  arr and dlna see an empty `/mnt/media` or `/mnt/programs` while Proxmox
  shows the storage as inactive. Remount, then restart the containers with
  bind mounts so they pick up the new mounts:

  ```sh
  ssh shane@<cube> 'for s in appdata media programs; do sudo umount -l /mnt/pve/unraid-$s; done; sudo pvesm status'
  ssh shane@<cube>
  sudo pct list | awk '$NF ~ /^(plex|arr|dlna)$/ {print $1}' | xargs -n1 sudo pct reboot
  ```

  If a manual mount says `Operation not permitted`, the NAS isn't exporting
  yet, usually because its pool hasn't mounted.
