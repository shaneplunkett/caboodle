# Arr

NixOS LXC on Cube running the media automation stack, one module file per
app.

## How the apps find each other

The apps keep their connections to each other (download clients, Prowlarr's
app sync, Seerr's servers) in their own databases, as the host's LAN address
and each app's port. Nix can't declare any of that, so moving or rebuilding
the host has to keep:

- **The address.** It's the host's `lanAddress`, which Terraform reserves
  for the container's MAC.
- **The ports.** Sonarr Anime is a second Sonarr on its own port, not a
  remapped container port.
- **The API keys.** Sonarr, Sonarr Anime, Radarr, Prowlarr and SABnzbd get
  theirs from agenix. Seerr, Tautulli, Maintainerr and Shelfarr keep theirs in
  their data folders, and Deluge's web password (what Sonarr and Radarr log in
  with) is in `web.conf`.

## Media

The `unraid-media` pool is bind-mounted at `/mnt/media`, the same path as
Plex, and the apps store their paths under it. Unraid's NFS export squashes
every user to `nobody:users`, so the services run as their normal NixOS users
and files still land as 99:100.

## Containers

Maintainerr, Shelfarr, Calibre-Web-Automated and Dispatcharr have no NixOS
module, so they run under Podman with `virtualisation.oci-containers`. Renovate opens the
pull requests that move their images.

- **Podman needs `XDG_RUNTIME_DIR=/run`.** Without it, rootful Podman puts
  network namespaces in `/run/user/0`, and every root SSH login (like a
  colmena deploy) mounts a fresh tmpfs over that folder. Podman then can't
  find the namespace to tear down, leaves the old port forward behind, and the
  port points at a dead container after the next restart.
- **Shelfarr binds port 80 as a normal user.** Docker allows that inside
  containers by default and Podman doesn't, so it gets
  `net.ipv4.ip_unprivileged_port_start=0`.
- **Calibre-Web-Automated imports whatever lands in the books-ingest folder**
  into the real library. Never run two of them against the same share.

## SABnzbd

Nix writes its settings into `sabnzbd.ini` on each start, and they win over
anything set in the web UI.

- The ini is writable (`allowConfigWrite`). Read-only, SABnzbd still tries
  to save it every 30 seconds or so, and fills the Warnings tab with "Cannot
  write to INI file".
- Settings changed only in the web UI live in `sabnzbd.ini`, which isn't
  backed up because it holds the credentials. Anything worth keeping belongs
  in Nix.

## Deluge

`core.conf` and the daemon's `auth` come from Nix. The web password and
labels are state in the data folder.

- The NixOS module creates the download folders with tmpfiles, which would
  `chmod` and `chown` them on the Unraid share. Those entries are forced
  empty so Nix never touches share permissions.
- Torrents are outgoing only. Deluge uses a random listening port and
  nothing is forwarded to it.

## Dispatcharr

Dispatcharr feeds Plex internet TV streams as an HDHomeRun.
[dispatcharr.md](dispatcharr.md) covers setting it up, Plex and its gotchas.

## Restoring a database

The SQLite databases are backed up as dumps in a `dumps/` folder next to
them. Follow the restore steps in [docs/hetzner](../hetzner/README.md) for
the app's folder. Then, with the app stopped, copy the dump from `dumps/`
over the database, delete its `-wal` and `-shm` files, and start the app.
