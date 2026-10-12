# Plex

NixOS LXC on Cube running `services.plex`, with the Intel iGPU passed through
for hardware transcoding. The container is `module "plex"` in
`terraform/cube-plex.tf` and the service is `modules/services/plex`.

## iGPU and media

Proxmox only lets `root@pam` set device passthrough and bind mounts, so the
`nixos-lxc` module's `devices` and `bind_mounts` apply them over SSH with
`pct set` and reboot the container. Only the render node is passed through,
owned by NixOS's `render` group (gid 303) inside the container, which the
`plex` user is in. Plex downloads its own VA-API drivers into `Drivers/`, so
the host needs nothing extra.

Media is the `unraid-media` storage pool bind-mounted at `/mnt/media`, the same
path the arr LXC uses, so library paths match.

## Remote access

The gateway's WAN port forward for 32400 is the only thing in the homelab
exposed directly to the internet. The Plex module declares it with
`homelab.portForwards`, and Terraform points it at Plex's `lanAddress`.
Shared users (family) reach the server through plex.tv, which knows it by the
machine identifier in `Preferences.xml`.

So anything that rebuilds or moves Plex has to keep both:

- **The MAC address.** `mac_address` in the Terraform keeps the UniFi
  reservation pointing at the same container.
- **`Preferences.xml`.** Without it Plex starts as a new, unclaimed server and
  every share has to be redone.

Check remote access from the host itself, where `mappingState="mapped"` means
plex.tv reached it from outside:

```sh
t=$(grep -o 'PlexOnlineToken="[^"]*' "/var/lib/plex/Plex Media Server/Preferences.xml" | cut -d'"' -f2)
curl -s "http://127.0.0.1:32400/myplex/account?X-Plex-Token=$t" | grep -o 'mapping[A-Za-z]*="[^"]*"'
```

## Backups

Only what can't be rebuilt is backed up: `Preferences.xml` and the databases
(watch history, libraries, settings). Metadata, thumbnails and the cache
come back on a library refresh.

The live databases are excluded. Before each run, `prepare` takes a
consistent `.backup` of each one into `/var/lib/plex/backup`, as the `plex`
user so it never leaves root-owned `-wal`/`-shm` files Plex can't open.

To restore, follow the restore steps in [docs/hetzner](../hetzner/README.md)
for `/var/lib/plex`, then with Plex stopped, copy each dump from `backup/`
over its file in `Plug-in Support/Databases/`, delete the matching `-wal` and
`-shm` files, and start Plex.
