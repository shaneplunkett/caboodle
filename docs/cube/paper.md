# Paper

NixOS LXC on cube running Paperless-ngx, for Shane's documents and receipts.
It lives at `https://paper.shaneplunkett.com`.

## Sign-in

Paperless's own OIDC login with Pocket ID. The password form is off and the
login page goes straight to Pocket ID. A first sign-in makes the account, and
anyone in the `paperless_admins` group signs in as a superuser. That group
is checked on every sign-in, so leaving it takes the admin away next time.

If Pocket ID is down or the group goes missing, make a local superuser on the
host with `paperless-manage createsuperuser` and sign in at `/admin/`.

Phone apps sign in with an API token from My Profile in the web UI.

## Secrets

`paperless-env` is an env file with Paperless's OIDC config, which holds the
client secret, both API keys, and Shane's date of birth for
`PAPERLESS_IGNORE_DATES`. That date is on most medical and government
letters, and Paperless otherwise files them under it. It's in the secret
because the repo is mirrored to GitHub. The OIDC JSON goes in single quotes so
systemd and bash read it the same way. From `modules/agenix`:

```sh
providers=$(jq -cn --arg secret "$(rbw get paperless-oidc-client-secret)" '{openid_connect: {
  SCOPE: ["openid", "profile", "email", "groups"],
  OAUTH_PKCE_ENABLED: true,
  APPS: [{provider_id: "pocket-id", name: "Pocket ID", client_id: "paperless", secret: $secret,
    settings: {server_url: "https://auth.shaneplunkett.com"}}]}}')
{
  printf "PAPERLESS_SOCIALACCOUNT_PROVIDERS='%s'\n" "$providers"
  printf 'PAPERLESS_AI_LLM_API_KEY=%s\n' "$(rbw get paperless-anthropic-api-key)"
  printf 'PAPERLESS_AI_LLM_EMBEDDING_API_KEY=%s\n' "$(rbw get paperless-openai-api-key)"
  printf 'PAPERLESS_IGNORE_DATES=%s\n' "$(rbw get paperless-ignore-dates)"
} | agenix -e paperless-env.age
unset providers
```

## AI

Suggestions and document chat use Claude Haiku through Anthropic's
OpenAI-compatible endpoint, and embeddings use OpenAI. Document text goes to
both.

- **Temperature is pinned to 1.** Paperless's LLM library sends 0.1, and
  current Claude models reject anything below 1.
- **Set the embedding endpoint and key.** Left unset, Paperless falls back
  to the LLM's, which assumes one provider does both. Anthropic has no
  embeddings API.
- **Haiku, not Sonnet or Opus.** Suggestions force a tool call, which Sonnet
  5.5 and Opus 5.5 reject.

## Duplicates

Paperless 3 keeps duplicate uploads by default. Here it rejects them, so
the iCloud backlog can go in without tracking what's already there. A
duplicate means the same file byte for byte, so two scans of one letter
both get in.

## Backups

The nightly backup runs Paperless's exporter first and backs up its output,
which holds the originals, the archived copies and a manifest of everything
in the database. The exporter stops Paperless while it runs, so the unit
alerts wait 15 minutes.

To restore, rebuild the host, `restic-homelab restore` `/var/lib/paperless/export`,
and run `paperless-manage document_importer /var/lib/paperless/export` on the
empty install.

## Updates

Database migrations run on start, so an update's rollback is a restore.
