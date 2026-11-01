# Hetzner

A Hetzner Storage Box is the offsite restic target for the servers' backups. It's
defined in `terraform/hetzner.tf`, with state in Terraform Cloud, and applied
from the desktop with `scripts/terraform.sh apply`.

## Nix host backups

Nix hosts are rebuilt from git, so only their data is backed up, from each
service's `homelab.backup.paths`. A host's restic jobs share a lock, so
maintenance waits for a backup instead of failing it.

Each host gets its own Storage Box subaccount, which only sees its own
folder. restic reaches it through rclone's SFTP backend, because subaccounts
only take passwords.

A third copy goes to the host's own Cloudflare R2 bucket, with a token that
can only reach that bucket. The R2 backup runs after the Storage Box one,
even if that failed, so their `prepare` dumps never overlap. R2 doesn't
charge for egress, so restoring from it is free.

### Adding a host

1. Add it to `local.backup_hosts` in `terraform/locals.tf` and apply. That
   makes its subaccount and its R2 bucket.
2. Make it a restic password: `rbw generate --no-symbols 48 restic-<host> > /dev/null`.
3. Add `backup-<host>.age` to `modules/agenix/agenix-rules.nix` with
   the host as a recipient, then from `modules/agenix`:

   ```sh
   host=<host>
   login=$(terraform -chdir=../../terraform output -json storage_box_subaccounts)
   {
     printf 'RESTIC_PASSWORD=%s\n' "$(rbw get "restic-$host")"
     printf 'RCLONE_SFTP_USER=%s\n' "$(jq -r --arg h "$host" '.[$h].username' <<<"$login")"
     printf 'RCLONE_SFTP_PASS=%s\n' "$(jq -r --arg h "$host" '.[$h].password' <<<"$login" | rclone obscure -)"
   } | agenix -e "backup-$host.age"
   unset login
   ```

4. Add `backup-r2-<host>.age` the same way, from the bucket token Terraform
   made for the host:

   ```sh
   creds=$(terraform -chdir=../../terraform output -json r2_backup_credentials)
   {
     printf 'RESTIC_PASSWORD=%s\n' "$(rbw get "restic-$host")"
     printf 'AWS_ACCESS_KEY_ID=%s\n' "$(jq -r --arg h "$host" '.[$h].access_key_id' <<<"$creds")"
     printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$(jq -r --arg h "$host" '.[$h].secret_access_key' <<<"$creds")"
   } | agenix -e "backup-r2-$host.age"
   unset creds
   ```

5. Give a service on the host some `homelab.backup.paths` and deploy.

### Restoring a host's data

On the host, `restic-homelab` is restic with the host's repo and
credentials already set:

```sh
restic-homelab snapshots
systemctl stop <units>
restic-homelab restore latest --target / --include <path>
systemctl start <units>
```

Stop every unit that writes under the path. For FreshRSS that's
`phpfpm-freshrss` and `freshrss-updater.timer`, since there's no `freshrss`
unit. `restic-r2` is the same for the host's R2 bucket, if the Storage Box is
the thing that's gone.

If the host is gone, rebuild it first (the README's "Adding a host"), and its
secret will decrypt once its new key is a recipient and the secrets are
rekeyed. Restore before its first nightly backup, or that backup of an empty
service becomes `latest`. To read a repo from a laptop instead, set the same variables by
hand in the dev shell, which has restic and rclone:

```sh
export RESTIC_REPOSITORY=rclone::sftp:restic RCLONE_SFTP_HOST=<box> RCLONE_SFTP_PORT=23
export RCLONE_SFTP_USER=... RCLONE_SFTP_PASS=... RESTIC_PASSWORD=...
restic snapshots
```

A service with a `prepare` step backs up a dump rather than its live files,
so restore that, copy it into place while the service is stopped, and chown
it to the service's user. For FreshRSS that's `users/<user>/backup.sqlite`
over `db.sqlite`.

### Monitoring

Besides each host's backup alerts, the monitoring host watches the box
itself, its SFTP and its usage, since a full box fails every host at once.

## Retired services

Their final archives are on the box under `<service>-final-archives/`.

## Gotchas

- **Keep the restic password to letters and digits.** systemd reads the
  host's secret as an env file and the `restic-homelab` wrapper sources it
  with bash, and the two disagree about quotes and symbols.
- **List every host key type of the box** in known_hosts. rclone accepts
  whichever one the box offers, and a missing type is a "key mismatch".
- **The SFTP probe is IPv4.** Blackbox prefers IPv6, the box has an AAAA
  record, and the guests have no IPv6 route.
- **Subaccount usernames come from Hetzner** (`<box>-subN`), so they live in
  each host's secret rather than in Nix.
- **The usage API needs a token**, kept as the `hetzner-api-token` secret on
  the monitoring host. A read-only token is enough.
- **Back up real paths, not symlinks.** Services with `DynamicUser` keep
  their state in `/var/lib/private/<name>`, and `/var/lib/<name>` is a
  symlink restic would store as just a link.
- **Nothing under `/mnt` gets backed up.** That's where the NAS shares are
  mounted, so the module refuses those paths and restic stays on one
  filesystem.
- **A restored dump is owned by root**, since the backup runs as root.
  Copied over an existing file it keeps that file's owner, but a rebuilt host
  has no file to copy over. The service still opens a root-owned database
  and silently saves nothing: FreshRSS refreshed all 28 feeds and stored
  none of the new articles.
- **A restore brings back only what the paths kept.** Excluded folders like
  FreshRSS's `cache` come back missing. The service makes them on a real
  host, but a restore into a scratch folder needs them made by hand, or
  FreshRSS refuses to refresh.
- **SFTP paths must be relative**: `./backups`, not `/backups`.
- **SSH is on port 23**, not 22.
