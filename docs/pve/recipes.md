# Recipes

Incus guest on PVE running Norish, the recipe app at
`https://recipes.shaneplunkett.com`. It holds the Red Book and Ben Shewry's
Chef v Air Fryer recipes, plans meals and keeps the shopping list. The
service is `modules/services/norish`.

## How it runs

Norish and Obscura, the headless browser it renders pages with for URL
imports, run as containers. Postgres and Redis run on the guest itself.

- **Norish shares the guest's network** and reaches Postgres over its
  socket, mounted at `/run/postgresql`. The server in the image runs as uid
  1000, so the guest has a `norish` user with that uid, which is how peer
  auth lets it in as the `norish` role without a password.
- **Obscura stays on its own network**, published only on loopback, so a
  page it renders can't reach Postgres or Redis on the guest's localhost.
- **Uploads live in `/var/lib/norish`**: recipe photos, avatars and videos.

## Sign-in

Norish's own OIDC login with Pocket ID. Anyone in `norish_admins` can sign
in, and the group makes them a Norish admin. The first person to sign in
becomes the owner, and registration closes after them. Password login is off
because OIDC is set, so nobody gets in while Pocket ID is down.

## Secrets

`norish-env` holds the master key and the OIDC client secret, and
`norish-obscura-env` the token Norish and Obscura share. From
`modules/agenix`:

```sh
{
  printf 'MASTER_KEY=%s\n' "$(rbw get norish-master-key)"
  printf 'OIDC_CLIENT_SECRET=%s\n' "$(rbw get norish-oidc-client-secret)"
} | agenix -e norish-env.age
printf 'OBSCURA_CDP_TOKEN=%s\n' "$(rbw get norish-obscura-token)" | agenix -e norish-obscura-env.age
```

**Never change the master key.** Norish derives the keys it encrypts stored
secrets with from it, so a new one makes them unreadable. A restore needs the
same key, which is in Bitwarden.

## Backups

Restic backs up the uploads and a `pg_dump` of the database, made just
before each backup into `/var/backup/norish`. To restore:

```sh
ssh root@recipes
restic-homelab restore latest --target /root/restore --include /var/lib/norish --include /var/backup/norish
systemctl stop podman-norish
runuser -u postgres -- dropdb norish
runuser -u postgres -- createdb -O norish norish
runuser -u postgres -- pg_restore --no-owner --role=norish -d norish /root/restore/var/backup/norish/norish.dump
rsync -a --delete /root/restore/var/lib/norish/ /var/lib/norish/
systemctl start podman-norish
```

## Gotchas

- **The admin UI can take OIDC away from Nix.** Norish copies the `OIDC_*`
  settings into its database on every start, unless the provider has been
  edited under **Settings > Admin**, which marks it overridden. After that
  the env is ignored until the override is reset there.
- **The API key is per user,** under **Settings > User > API keys**. The
  API is documented at `https://docs.norish.dev/reference/api`.

Throwaway line for SHA-272.
