# Paper

Incus guest on Cube running Paperless-ngx, for Shane's documents and
receipts. It lives at `https://paper.shaneplunkett.com`.

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

## paperless-gpt

paperless-gpt re-reads scans with Claude Haiku's vision, for documents
Tesseract garbles. Tag a document `paperless-gpt-ocr-auto`, and on its next
poll, every ten seconds, it renders each page, sends the images to
Anthropic, and writes the text back into the document's content. It then
swaps the tag for `paperless-gpt-ocr-complete`, or `paperless-gpt-failed`
if it gave up. Beyond that tag, only the content changes: the original file,
the archived PDF and the title stay as they were. Titles and tags stay with
Paperless's own AI.

Its UI at `https://papergpt.shaneplunkett.com` has no login, so it sits
behind the oauth2-proxy gate, and the host's firewall only lets the ingress
and the dashboard reach its port.

- **Leave `paperless-gpt-auto` unused.** That tag runs its title, tag and
  metadata suggestions, which would fight Paperless's.
- **`OCR_LIMIT_PAGES` is 0.** Upstream reads only the first 5 pages, and
  saves the truncated text over the full content.
- **`VISION_LLM_MAX_TOKENS` is 16000.** Without it each page gets 2048
  tokens, and Haiku spends those thinking before it writes. A page that runs
  out comes back blank.
- **OCR settings saved in its UI win over the module's.** They land in
  `config/settings.json`, and the OCR page can reset them.

`paperless-gpt-env` holds an API token for Paperless, from My Profile, and
an Anthropic key. From `modules/agenix`:

```sh
{
  printf 'PAPERLESS_API_TOKEN=%s\n' "$(rbw get paperless-gpt-api-token)"
  printf 'ANTHROPIC_API_KEY=%s\n' "$(rbw get paperless-anthropic-api-key)"
} | agenix -e paperless-gpt-env.age
```

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
