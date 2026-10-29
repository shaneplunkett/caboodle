# Plex

Incus guest on Cube running Plex, with the Intel iGPU passed through for
hardware transcoding.

## iGPU and media

Only the render node is passed through. Plex downloads its own VA-API
drivers into `Drivers/`, so the host needs nothing extra.

Media is the NAS's Media share passed in at `/mnt/media`, the same path arr
uses, so library paths match.

## Remote access

Shared users (family) reach the server through plex.tv, which knows it by
the machine identifier in `Preferences.xml`, and through the gateway's port
forward to Plex's address. So anything that rebuilds or moves Plex has to
keep both:

- **The MAC address.** `mac` in plex's `homelab.guest` keeps the UniFi
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

The backup covers Plex's data folder, minus what a library refresh brings
back. The databases go in as dumps, taken as the `plex` user so they never
leave root-owned `-wal`/`-shm` files Plex can't open.

To restore, follow the restore steps in [docs/hetzner](../hetzner/README.md)
for `/var/lib/plex`, then with Plex stopped, copy each dump from `backup/`
over its file in `Plug-in Support/Databases/`, delete the matching `-wal` and
`-shm` files, and start Plex.
