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

Dispatcharr turns internet TV streams into a tuner Plex can watch and record
from, by pretending to be an HDHomeRun. It covers free-to-air while the
building aerial is down. [The research](../research/2026-10-25-iptv-into-plex-dvr.md)
has the options and sources behind it.

Its web UI sits behind the oauth2-proxy gate. Dispatcharr has no OIDC and
no way to skip its login for local addresses, so it signs you in from the
`X-Email` header the gate sends instead. It only believes that header from
the ingress host, which `DISPATCHARR_TRUSTED_PROXIES` names. Plex skips
ingress and talks to the port on the LAN.

To set it up, in Dispatcharr:

1. Make the admin with the same email as your Pocket ID account, since the
   header is matched to an account by username and then by email. Its
   password is the way in when Pocket ID is down.
2. Turn on Settings, Reverse Proxy Auth, with the header `X-Email`.
3. Add the M3U `https://i.mjh.nz/au/Melbourne/kodi-tv.m3u8`. The
   `tvh-tv.m3u8` next to it pipes through ffmpeg for Tvheadend, which
   Dispatcharr can't use.
4. Add the EPG `https://i.mjh.nz/au/Melbourne/epg.xml.gz`.
5. Make the channels and match them to the guide.

Then in Plex, under Live TV & DVR, add a device by hand at
`http://192.168.1.90:9191/hdhr`.

- **The default trusted proxies never sign anyone in.** Unset, Dispatcharr
  trusts private addresses for client IPs but not for sign-in, so the
  ingress has to be named.
- **Seven only works from an Australian IP.** Traffic out of a VPN breaks
  it.
- **Plex doesn't support emulated tuners.** They work, but a Plex update can
  break them, as 1.43.0 did for a while.
- **Plex wants one type of tuner per DVR.** Give Dispatcharr its own DVR
  rather than adding it next to the HDHomeRun.

Dispatcharr's Postgres lives in `db/`, which the backup skips because a
live copy of it is useless. Dispatcharr dumps the database into `backups/`
every night at 3am instead and keeps three. To restore, put the files back
as in [docs/hetzner](../hetzner/README.md), start the container, and restore
the newest dump from Dispatcharr's Backups page.

## Restoring a database

The SQLite databases are backed up as dumps in a `dumps/` folder next to
them. Follow the restore steps in [docs/hetzner](../hetzner/README.md) for
the app's folder. Then, with the app stopped, copy the dump from `dumps/`
over the database, delete its `-wal` and `-shm` files, and start the app.
