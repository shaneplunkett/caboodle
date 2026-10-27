# Photos

NixOS LXC on cube running Immich, for Shane's photo library and iPhone
backup.

## Storage

Everything lives on the container's own disk, on cube's NVMe. Nothing is on
the NAS, so the stale NFS mounts in [README.md](README.md) can't take it
down.

The disk alert is also the "library is filling up" alert. Grow the disk in
the Terraform before it fills.

## Settings

Nix owns Immich's settings (`services.immich.settings`), so the admin
settings pages are read-only. Change them in the module and land a PR.

## Sign-in

Immich's own OAuth with Pocket ID. The client's ID is a generated UUID,
because the custom ID didn't stick when it was made, so the module names
that. The login page goes straight to Pocket ID, and sign-ups are off, so
only existing Immich accounts get in. The password login stays as a
break-glass at `https://photos.shaneplunkett.com/auth/login?autoLaunch=0`,
with the password in Bitwarden.

Immich matches a Pocket ID sign-in to an account by email, so the two have
to agree. To give someone else access, make their account in Immich's admin
pages with their Pocket ID email, and add them to the `immich_users` group
in Pocket ID.

## iPhone app

Server URL is `https://photos.shaneplunkett.com`, which works at home and
over Tailscale. Turn on Background App Refresh for Immich, and Tailscale's
VPN On Demand so it can upload away from home. iOS decides when background
backups run, so opening the app is what reliably kicks one off.

## Importing

iCloud comes in through the app's own backup, with all albums selected.
Google Takeout goes in with `immich-go upload from-google-photos` and an API
key made in Immich.

## Updates

Updates are one-way. Database migrations run on start, so the rollback is a
restore. Read the release notes in any flake update pull request that bumps
Immich.

## Backups

Immich's own database dump is the database backup. The host runs on UTC and
Immich's cron follows the host clock, so the dump time is set in UTC to land
before the nightly backup, which runs on Melbourne time.

To restore, rebuild the host, `restic-homelab restore` `/var/lib/immich` with
Immich stopped, start it on the empty database, and pick Restore from backup
on the welcome screen.
