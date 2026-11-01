# Auth

NixOS Incus container on PVE running Pocket ID, Shane's single sign-on.
It's an OIDC provider that only does passkeys, so there are no passwords
anywhere. Its size is `homelab.guest` in `flake.nix`, `terraform/incus.tf`
makes it, and the service is `modules/services/pocket-id`.

The admin UI is `https://auth.shaneplunkett.com`. Pocket ID publishes its
endpoints at `/.well-known/openid-configuration`, and most apps only need
that URL or the three endpoints in it.

## Adding an app

Check Pocket ID's [client examples](https://pocket-id.org/docs/client-examples)
first. They cover a lot of apps, and list the callback URL and scopes each
one wants.

1. Make the client secret, which saves it in Bitwarden:

   ```sh
   rbw generate --no-symbols 48 <app>-oidc-client-secret
   ```

2. Add `<app>-oidc-client-secret.age` to `modules/agenix/agenix-rules.nix`
   with the app's host **and `auth`** as recipients, then from
   `modules/agenix`:

   ```sh
   printf '%s' "$(rbw get <app>-oidc-client-secret)" | agenix -e <app>-oidc-client-secret.age
   ```

3. Declare the client in the app's module, keyed by its client ID. Use the
   app's name, so the Nix config can name it.

   ```nix
   homelab.oidcClients.<app> = {
     name = "<App>";
     callbackURLs = [ "<from the app's docs or the client example>" ];
     groups = [ "<app>_admins" ];
     secret = "<app>-oidc-client-secret";
   };
   ```

   Add `pkce = false;` if the app doesn't support PKCE. An app that isn't a
   host in the hive is declared in `modules/services/pocket-id`.
4. Point the app at Pocket ID in its module, reading the secret from
   `config.age.secrets.<app>-oidc-client-secret.path`.
   `modules/services/grafana` is the worked example.
5. Merge. The auth host creates the group and the client with that secret.
   A new group is empty, so add yourself to it in Pocket ID under User Groups,
   then sign in from the app's login page.

`secret` only matters when a client is created, so clients that already
exist, like forgejo, home and oauth2-proxy, declare none. Changing it later
does nothing. Clients are never deleted either, so one removed from Nix stays
in Pocket ID until it's deleted there. The `pocket-id-clients` job's report is
in `journalctl -u pocket-id-clients` on auth.

### Roles

Pocket ID sends a `groups` claim when the app asks for the `groups` scope.
Map roles from group names rather than emails. Grafana makes members of
`grafana_admins` an Admin and everyone else a Viewer. Use the same
`<app>_admins` pattern for the next app.

The group's name is what goes in the claim, not its display name.

### Apps without OIDC

Apps with no OIDC login of their own sit behind oauth2-proxy on the ingress
host. A route goes behind it by adding its name to `gated` in
`modules/services/nginx-ingress`, with the paths that should stay open. One
sign-in covers every gated app.

The open paths are how the apps talk to each other through ingress, like
Maintainerr calling the arr apps on `/api/`, or SABnzbd fetching NZBs from
Prowlarr. Every open path still needs that app's API key. Before gating a new
app, search the arr host's `/var/lib` for its hostname to find what calls it.

- **Pocket ID doesn't verify emails** without a mail server, so every
  `email_verified` claim is false. oauth2-proxy refuses those by default,
  which shows up as a 500 after signing in. It runs with
  `insecure-oidc-allow-unverified-email`, which is safe because the group
  decides who gets in, not the email.
- **The apps' own ports are still open on the LAN**, so the gate only covers
  the `shaneplunkett.com` names.
- **Behind the gate, the apps skip their own logins,** because ingress counts
  as a local address. Deluge's web password can't be turned off, so it still
  asks.

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
