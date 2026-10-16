# Forge

NixOS LXC on PVE running Forgejo, Shane's git forge. The container is
`module "forge"` in `terraform/pve-forge.tf`, and the service is
`modules/services/forgejo`.

The web UI is `https://git.shaneplunkett.com`, through ingress. SSH clones
go straight to the host over the tailnet, as
`forgejo@forge:<owner>/<repo>.git`.

## Signing in

Sign-in goes through Pocket ID, using the `forgejo` client. Members of
`forgejo_admins` become admins.

The Nix module sets the `pocket-id` auth source on deploy, so change it
there. Edits under Site Administration, Authentication Sources get
overwritten on the next deploy that touches it.

## Actions

Workflows live in `.forgejo/workflows/` and run on the builder. See
[builder.md](builder.md). `ForgejoWorkflowFailing` fires in Discord when the
last run of a workflow on a default branch failed.

## Configuration in Terraform

`terraform/forge-config.tf` holds the forge settings that matter: who can
write where, and repos that other repos depend on. Everything else, including
most repos, stays in the UI. Forgejo has no settings file inside a repo, so a
per-repo exception goes in Terraform next to the default it overrides.

- **`bots`** gives `forge-bot` write access to every repo. Renovate runs
  as `forge-bot`, so it opens an onboarding pull request on every new repo.
  Closing it without merging tells Renovate to leave that repo alone.
- **`workflows`** holds the workflows other repos call. Forgejo only expands
  a workflow from another repo when its owner is public, so the `shane` org
  is public. That's set by hand, because the provider can't import an org
  and the API can't set an org public. The sign-in requirement still hides
  everything from anyone not signed in.
- **`caboodle`'s `main`** requires the build check before a merge.
  [builder.md](builder.md) covers why.

Terraform signs in with `terraform-forgejo-token`, a token from Shane's
account (an org owner) with read and write on organization and repository
and read on user. It's in Bitwarden as `homelab_forgejo_terraform_token` and
in agenix for the builder. Terraform runs on the forge's own runner, so if
the forge is down, fix it with colmena first.

## Getting back in

`forgejo-admin` on the host runs `forgejo admin` as the service user, with
the right paths set. If Pocket ID is down, make a local admin and sign in
with the password it prints:

```sh
ssh root@forge forgejo-admin user create --admin --username <name> --email <email> --random-password
```

## Backups and restores

A restore needs both the database dump and `/var/lib/forgejo`, which holds
the repositories and the secrets Forgejo generated for itself.

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
