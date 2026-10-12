# Photos

NixOS LXC on cube running Immich with the nixpkgs `services.immich` module,
for Shane's photo library and iPhone backup. The container is
`module "photos"` in `terraform/cube-photos.tf` and the service is
`modules/services/immich`. Why it's built this way is in
[docs/research/immich.md](../research/immich.md).

## Storage

Everything lives on the container's own disk, on cube's `nvme-thin` pool:
originals and thumbnails in `/var/lib/immich`, Postgres in
`/var/lib/postgresql`. Nothing is on Unraid, so the stale NFS mounts in
[README.md](README.md) can't take it down.

The disk alert is also the "library is filling up" alert. Grow the disk in
the Terraform before it fills.

## Settings

Nix owns Immich's settings (`services.immich.settings`), so the admin
settings pages are read-only. Change them in the module and land a PR.

## Sign-in

Immich's own OAuth with Pocket ID, client ID `immich`. The login page goes
straight to Pocket ID, and sign-ups are off, so only existing Immich accounts
get in. The password login stays as a break-glass at
`https://photos.shaneplunkett.com/auth/login?autoLaunch=0`, with the password
in Bitwarden.

To give someone else access, make their account in Immich's admin pages with
the same email as their Pocket ID account.

## iPhone app

Server URL is `https://photos.shaneplunkett.com`, which works at home and
over Tailscale. Turn on Background App Refresh for Immich, and Tailscale's
VPN On Demand so it can upload away from home. iOS decides when background
backups run, so opening the app is what reliably kicks one off.

## Importing

- **iCloud:** the app's own backup, with all albums selected. It downloads
  each iCloud original, uploads it and deletes the local copy. Do the first
  run at home, plugged in, with the app open.
- **Google Takeout:** `immich-go upload from-google-photos` with an API key
  made in Immich, after the iCloud run. Exact copies are skipped. Google's
  compressed copies show up in Utilities, Review duplicates, which keeps the
  bigger file by default.

## Backups

The backup module sends all of `/var/lib/immich` to the Storage Box. Immich
dumps its database into `/var/lib/immich/backups` at 2am, before restic
runs, so the dump is the database backup and Postgres's live files are left
out.

To restore, rebuild the host, `restic-homelab restore` `/var/lib/immich` with
Immich stopped, start it on the empty database, and pick Restore from backup
on the welcome screen.
