# Auth

NixOS LXC on PVE running Pocket ID, the homelab's single sign-on. It's an
OIDC provider that only does passkeys, so there are no passwords anywhere.
The container is `module "auth"` in `terraform/pve-auth.tf`, and the service
is `modules/services/pocket-id`, using the nixpkgs module.

The admin UI is `https://auth.shaneplunkett.com`. Pocket ID publishes its
endpoints at `/.well-known/openid-configuration`, and most apps only need
that URL or the three endpoints in it.

## Adding an app

Check Pocket ID's [client examples](https://pocket-id.org/docs/client-examples)
first. They cover a lot of apps, including Proxmox and Unraid, and list the
callback URL and scopes each one wants.

1. In Pocket ID, open OIDC Clients and add one:
   - Pick Confidential Client. Public Client is for apps with no backend to
     keep a secret, which none of ours are.
   - The callback URL comes from the app's docs or the client example.
   - Click Set custom client ID, next to Create at the bottom of the form,
     and use the app's name, like `grafana`, so the Nix config can name it
     instead of a random UUID. It's a link that opens the field, so it's
     easy to skip, and the ID can't be changed afterwards. That's what
     happened to oauth2-proxy's and Immich's clients, and it's fine to use
     the UUID instead.
   - Turn PKCE on if the app supports it.
   - Turn Skip Consent Screen on. These are all our own apps.
   - Leave Re-Authentication and Pushed Authorization Requests off.
2. Saving doesn't show a secret. Open the client again, add one under Client
   secrets, and save it in Bitwarden as `<app>-oidc-client-secret`. Pocket ID
   only shows it once.
3. Add `<app>-oidc-client-secret.age` to `modules/agenix/agenix-rules.nix`
   with the app's host as a recipient, then from `modules/agenix`:

   ```sh
   printf '%s' "$(rbw get <app>-oidc-client-secret)" | agenix -e <app>-oidc-client-secret.age
   ```

4. Point the app at Pocket ID in its module, reading the secret from
   `config.age.secrets.<app>-oidc-client-secret.path`.
   `modules/services/grafana` is the worked example.
5. `colmena apply --on <host>`, then sign in from the app's login page.

### Roles

Pocket ID sends a `groups` claim when the app asks for the `groups` scope.
Map roles from group names rather than emails. Grafana makes members of
`grafana_admins` an Admin and everyone else a Viewer. Use the same
`<app>_admins` pattern for the next app.

Groups live in Pocket ID under User Groups. The group's name is what goes in
the claim, not its display name.

### Proxmox

The realm is cluster-wide, and Terraform can't manage it. The Terraform
token's role has no `Realm.Allocate` or `Permissions.Modify`, and adding
`Permissions.Modify` would let it grant itself anything. So the realm was
made once by hand. To make it again, from this repo:

```sh
printf '%s\n' "$(rbw get proxmox-oidc-client-secret)" | ssh shane@<pve> 'sudo bash -c '\''
read -r key
pveum realm add pocket-id --type openid --comment "Pocket ID" \
  --issuer-url https://auth.shaneplunkett.com --client-id proxmox --client-key "$key" \
  --scopes "email profile groups" --username-claim username \
  --autocreate 1 --groups-claim groups --groups-overwrite 1 --default 1
pveum group add proxmox_admins-pocket-id
pveum acl modify / --groups proxmox_admins-pocket-id --roles Administrator
'\'''
```

The secret goes in on stdin so it stays out of sudo's log.

- **Proxmox renames groups.** It adds the realm to each group from the claim,
  so `proxmox_admins` in Pocket ID becomes `proxmox_admins-pocket-id`. It
  only syncs groups that already exist in Proxmox, and the ACL is on that
  group.
- **Don't add `openid` to the scopes.** Proxmox adds it itself.
- **The callback is the bare origin,** `https://proxmox.shaneplunkett.com`.
  Signing in at a node's own address needs that origin added to the client.
- **The nodes need to resolve `auth.shaneplunkett.com`.** Proxmox fetches
  tokens itself, and the router doesn't know the homelab's names. Each node's
  DNS is in `terraform/proxmox-dns.tf`: Blocky on dns1 and dns2 first, the
  router last as a fallback.
- `shane@pam` is the way in when Pocket ID is down.

### Unraid

Unraid (7.2 or later) keeps OIDC in its own UI, under Settings, Management
Access, API, OIDC. It saves to
`/boot/config/plugins/dynamix.my.servers/configs/oidc.json` on the flash
drive.

- The callback is `https://unraid.shaneplunkett.com/graphql/api/auth/oidc/callback`.
- The issuer URL has no trailing slash.
- Add `groups` to the scopes, and use Advanced authorization with one rule,
  `groups` contains `unraid_admins`. Every OIDC login signs in as root, so
  this rule is the only thing deciding who gets in.
- The root password still works when Pocket ID is down.

### Apps without OIDC

Apps with no OIDC login of their own sit behind oauth2-proxy on the ingress
host, in `modules/services/nginx-ingress`. A route goes behind it by adding
its name to `gated`, with the paths that should stay open. Only members of
`media_admins` get through. One sign-in sets a cookie for the whole domain
that lasts 30 days, so it covers every gated app at once.

The open paths are how the apps talk to each other through ingress.
Maintainerr calls Sonarr, Radarr and Overseerr on `/api/`, Shelfarr calls
SABnzbd (which answers on both `/api` and `/sabnzbd/api`), and SABnzbd and Shelfarr fetch NZBs from Prowlarr's
`/<n>/download` links. Every open path still needs that app's API key. Before
gating a new app, search the arr host's `/var/lib` for its hostname to find
what calls it.

oauth2-proxy's own callback lives on `oauth.shaneplunkett.com`, which has
nothing else on it.

Glance's tiles for gated apps check the app's LAN address directly, using the
`/` proxy target from ingress. Through ingress, every gated app would redirect
to the sign-in page and look up even when the app was down.

- **Pocket ID doesn't verify emails** without a mail server, so every
  `email_verified` claim is false. oauth2-proxy refuses those by default,
  which shows up as a 500 after signing in. It runs with
  `insecure-oidc-allow-unverified-email`, which is safe because the group
  decides who gets in, not the email.
- **The apps' own ports are still open on the LAN**, so the gate only covers
  the `shaneplunkett.com` names.
- **Behind the gate, the apps skip their own logins.** Ingress counts as a
  local address, so the passkey is the only sign-in. The arr apps do this with
  `auth.required = "DisabledForLocalAddresses"`, and SABnzbd with
  `inet_exposure = 5`. Deluge's web password can't be turned off, so it still
  asks, but its session lasts 30 days instead of an idle hour. deluge-web
  owns `web.conf`, so Nix sets `session_timeout` there before each start.

## Getting back in

**If Pocket ID is down,** every app keeps its own local admin login. Keep
those in Bitwarden and don't disable the login form in any app.

**If the passkey is lost,** make a one-time sign-in link on the host:

```sh
ssh root@auth pocket-id-recover <username or email>
```

It prints a link that works once within the hour. Sign in with it and
register a new passkey.

## Backups and restores

The backup's `prepare` step copies the SQLite database to
`/var/lib/pocket-id/dumps` with `.backup`, and restic backs that up along
with the rest of `/var/lib/pocket-id`. The live database files are excluded.

Pocket ID encrypts its signing keys with the `pocket-id-encryption-key`
secret, so a restore is useless without it. The key is in agenix and in
Bitwarden under the same name.

To restore:

```sh
ssh root@auth
restic-homelab restore latest --target /root/restore --include /var/lib/pocket-id
systemctl stop pocket-id
rm /var/lib/pocket-id/data/pocket-id.db*
install -o pocket-id -g pocket-id -m 0600 \
  /root/restore/var/lib/pocket-id/dumps/pocket-id.db /var/lib/pocket-id/data/pocket-id.db
systemctl start pocket-id
```

## Gotchas

- **Passkeys need HTTPS on the real name.** A passkey belongs to
  `auth.shaneplunkett.com`, so the UI only works through ingress. The LAN
  address and port load, but sign-in fails there.
- **Don't change `APP_URL` casually.** Every app's config and every passkey
  is tied to it. Changing the hostname means registering passkeys again.
- **`TRUST_PROXY` is on**, because nginx terminates TLS. The nixpkgs option
  only takes a boolean, so Pocket ID trusts forwarded headers from anywhere.
  Something on the LAN talking to the port directly could fake the client IP
  in Pocket ID's audit log, but nothing more.
