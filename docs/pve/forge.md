# Forge

NixOS LXC on PVE running Forgejo, the homelab's git forge. The container is
`module "forge"` in `terraform/pve-forge.tf`, and the service is
`modules/services/forgejo`, using the nixpkgs module on a local PostgreSQL.

The web UI is `https://git.shaneplunkett.com`, through ingress. SSH clones
go straight to the host over the tailnet, as
`forgejo@forge:<owner>/<repo>.git`.

## Signing in

Sign-in goes through Pocket ID, using the `forgejo` client. The first sign-in
creates the account, named from the `preferred_username` claim, and members
of `forgejo_admins` become admins. There's no registration form, and nothing
is visible without signing in, including clones over HTTPS.

`forgejo-oidc.service` creates the `pocket-id` auth source, or updates it,
whenever the service changes, so the Nix module is the place to change it.
Edits under Site Administration, Authentication Sources get overwritten on
the next deploy that touches it.

## Actions

Workflows live in `.forgejo/workflows/` and run on the builder, which
`forgejo-runner-register` registers from a shared secret. See
[builder.md](builder.md).

Every five minutes, `forgejo-workflow-metrics` reads the database for the
last finished run of each workflow on each repo's default branch. A failed
one fires `ForgejoWorkflowFailing` in Discord, linked to the run, and the
alert resolves when a later run passes. Pull requests don't count, nor do
cancelled runs or repos with Actions switched off.

## Configuration in Terraform

`terraform/forge-config.tf` holds the forge settings that matter: who can
write where, and repos that other repos depend on. Everything else, including
most repos, stays in the UI. Forgejo has no settings file inside a repo, so a
per-repo exception goes in Terraform next to the default it overrides.

- **`bots`** is a team with `includes_all_repositories`, so it reaches repos
  made later too. It gives `forge-bot` and `vex` Write on code, pull
  requests, issues and Actions everywhere. Renovate runs as `forge-bot`, so it
  opens an onboarding pull request on every new repo. Closing it without
  merging tells Renovate to leave that repo alone.
- **`workflows`** holds the workflows other repos call with
  `uses: shane/workflows/.forgejo/workflows/<file>@<tag>`. Removing it from
  Terraform archives it rather than deleting it. Forgejo only expands a
  workflow from another repo when its owner is public, so the `shane` org is
  public. That's set by hand, because the provider can't import an org and
  the API can't set an org public. The sign-in requirement still hides
  everything from anyone not signed in.
- **`caboodle`'s `main`** requires the build check to pass before a pull
  request merges, so Renovate can hand its flake input updates to Forgejo
  to merge. `docs/pve/builder.md` covers why and what the contexts match.
  Pushing straight to `main` still works as before.

The provider is `svalabs/forgejo`, and it signs in with
`terraform-forgejo-token`, a token from Shane's account (an org owner) with
read and write on organization and repository and read on user. It's in
Bitwarden as `homelab_forgejo_terraform_token` and in agenix for the builder.
Terraform runs on the forge's own runner, so if the forge is down, fix it
with colmena first.

## Getting back in

`forgejo-admin` on the host runs `forgejo admin` as the service user, with
the right paths set. If Pocket ID is down, make a local admin and sign in
with the password it prints:

```sh
ssh root@forge forgejo-admin user create --admin --username <name> --email <email> --random-password
```

## Backups and restores

The backup's `prepare` step dumps the database to `/var/backup/forgejo` with
`pg_dump`, and restic backs that up along with `/var/lib/forgejo`: the
repositories, LFS objects, attachments, and the secrets Forgejo generated for
itself under `custom/conf`. A restore needs both halves.

To restore:

```sh
ssh root@forge
restic-homelab restore latest --target /root/restore \
  --include /var/lib/forgejo --include /var/backup/forgejo
systemctl stop forgejo
rm -rf /var/lib/forgejo
cp -a /root/restore/var/lib/forgejo /var/lib/
runuser -u postgres -- dropdb forgejo
runuser -u postgres -- createdb -O forgejo forgejo
runuser -u postgres -- pg_restore --no-owner --role=forgejo -d forgejo \
  < /root/restore/var/backup/forgejo/forgejo.dump
systemctl start forgejo
```

## Gotchas

- **The dump goes in through stdin.** `postgres` can't read files under
  `/root`, so `pg_restore` reads the dump from a redirect, which root's shell
  opens before switching user.
- **SSH doesn't go through ingress.** `git.shaneplunkett.com` resolves to
  the ingress host, which only proxies HTTP, so `SSH_DOMAIN` is the tailnet
  name `forge` instead.
- **The auth source's name is in the callback URL,**
  `/user/oauth2/pocket-id/callback`. Renaming it breaks sign-in until the
  Pocket ID client's callback is changed to match.
- **The client secret is on a command line.** `forgejo admin auth` only
  takes it as a flag, so it's briefly visible in the process list on forge
  while the auth source is set.
- **It runs the LTS release,** the nixpkgs default. Forgejo migrates its
  database forward on upgrade and can't go back, so moving to the latest
  release is a one-way choice.
