# Cube

## Summary

Secondary Proxmox host. Runs the always-on services that need to stay
stable and away from experiments on PVE.

Per-service docs:

- [arr.md](arr.md)
- [plex.md](plex.md)
- [photos.md](photos.md)
- [paper.md](paper.md)

## Unraid storage

Unraid's NFS shares are Proxmox storage pools (`terraform/storage.tf`), so Proxmox owns the mount lifecycle, reconnection, and health. You can see them in the web UI under Storage.

LXCs don't mount NFS themselves. They bind-mount the host path `/mnt/pve/<storage id>` instead.

## Gotchas

- **Unraid's shares go stale on Cube whenever Unraid restarts**, and the
  Media share can also come up empty after Cube itself reboots. Unraid's
  user shares hand out new file IDs each boot, so the kernel rejects the old
  mounts with `NFS: server <unraid> error: fileid changed` in `dmesg`,
  Proxmox shows the storage as inactive, and Plex, arr and dlna see an
  empty `/mnt/media` or `/mnt/programs`. Remount, then restart the
  containers with bind mounts so they pick up the new mounts:

  ```sh
  ssh shane@<cube> 'for s in appdata media programs; do sudo umount -l /mnt/pve/unraid-$s; done; sudo pvesm status'
  ssh shane@<cube>
  sudo pct list | awk '$NF ~ /^(plex|arr|dlna)$/ {print $1}' | xargs -n1 sudo pct reboot
  ```

  If a manual mount says `Operation not permitted`, Unraid isn't exporting
  yet, usually because its array hasn't been started.
