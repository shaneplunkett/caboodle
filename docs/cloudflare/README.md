# Cloudflare

Cloudflare is the registrar and DNS for the personal domains, and also runs Pages sites, Access and tunnels for the homelab.

## Tooling

Everything comes from the repo's `flake.nix` via direnv (`use flake` in `.envrc`).

- **Cloudflare MCP** (`.mcp.json`): the Code Mode server at `https://mcp.cloudflare.com/mcp`. It covers the whole API: DNS, DNSSEC, Registrar, Access, tunnels, Pages, Workers and analytics.
- **`cf`**: the official Cloudflare CLI (beta), a scriptable fallback for the same API. It isn't in nixpkgs yet, so the flake runs a pinned npm release through `npx`.
- **`wrangler`**: Workers and Pages projects only. It has no DNS, zone, Registrar or Access commands.
- **`cloudflared`**: tunnel runtime and management.
- **`dig`, `doggo`**: checking public DNS from outside the LAN's own answers.

Agent skills from `cloudflare/skills` (`cloudflare`, `cloudflare-one`, `wrangler`, `workers-best-practices`) are pinned in `skills-lock.json`.

## Credentials

- **Agents and local dev:** a user token, stored in rbw as `homelab_cf_token`. The password is the token and the username is the account ID. It's a user token because the Workers Builds API rejects account tokens with `12006 Invalid token`, whatever their permissions. Edit it in the dashboard under **My Profile → API Tokens**.
- **Terraform:** an account token, stored in rbw as `homelab_cf_terraform_token` and in agenix as `terraform-cloudflare-token` for the builder. It has Account API Tokens: Edit, so it can mint tokens with any permission and gets the same care as the Proxmox and Hetzner tokens. That also lets it update its own policies through the API (`PUT /accounts/{id}/tokens/{token_id}`), which is how to give it more permissions without the dashboard. Its zone permissions cover the personal zones only.

The ingress host's ACME renewals use a third token, scoped to DNS edit on the personal zones only, kept in agenix as `cloudflare-dns`. Terraform manages its permissions.

- `.envrc` exports the user token as `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` for `cf` and `wrangler`, and the Terraform token as `TF_VAR_cloudflare_api_token`.
- The MCP server reads the user token through `tools/cloudflare/mcp-headers.sh`, so it never sits in a config file.

Don't add client IP filtering to the user token, since the MCP server rejects IP-filtered tokens.

User token permissions:

| Scope | Permission | Level |
|-------|------------|-------|
| Account | Account Settings | Read |
| Account | Account Analytics | Read |
| Account | Access: Apps and Policies | Edit |
| Account | Access: Custom Pages | Edit |
| Account | Cloudflare Tunnel | Edit |
| Account | Cloudflare Pages | Edit |
| Account | Workers Scripts | Edit |
| Account | Workers Builds Configuration | Edit |
| Account | Registrar: Domains | Admin |
| Zone | Zone | Read |
| Zone | Zone Settings | Edit |
| Zone | DNS | Edit |
| Zone | Analytics | Read |

Zone permissions only take effect when the token's Zone Resources point at the account's zones. On the user token page, the Zone Resources section only appears once a permission row is set to Zone; set it to *Include → All zones from an account*. DNSSEC has no permission of its own; it needs DNS Edit.

## Gotchas

- Terraform owns these, in `terraform/cloudflare*.tf`. Change them in code, because a change made through the MCP or the dashboard gets reverted on the next apply.
  - the account tokens
  - the personal zones' DNS records and DNSSEC
  - the brain's tunnel and its routes
  - the Access apps and their policies
  - Red Book's Pages custom domain
- The repo and its plan comments are public, so private values reach Terraform through agenix as `sensitive` variables, the same way the provider tokens do. The Editor policy's emails are `terraform-access-emails`. The Vex CLI's service token stays out of Terraform, and its policy refers to it by ID.
- Some things stay out of Terraform on purpose. The Red Book Pages project belongs to its own repo's `wrangler` deploys. Martin's zones and his Workers custom domains belong to his site.
- The dashboard's account-token page has no zone picker. It puts every permission into one account-wide policy, so zone permissions save and display but grant nothing, and saving an account token there drops any zone policy added through the API. Change account tokens through Terraform.
- On the LAN, Blocky answers for all of `shaneplunkett.com` itself, so LAN lookups don't match the public answer. Ask public DNS instead, e.g. `dig @1.1.1.1` or `doggo @https://cloudflare-dns.com/dns-query`.
- The `cf` CLI is beta. Non-interactive deletes without `--force` print `Aborted.` and exit 0, so check the result rather than the exit code.
- The legacy Registrar `domains` list endpoint is end-of-life. Use `GET /accounts/{id}/registrar/registrations/{domain}` for `auto_renew` and `expires_at`.
- If the MCP server ever fails auth (for example, rbw was locked), Claude Code caches it as needing auth and stops connecting, even after the token works again. Remove the `cloudflare` key from `~/.claude/mcp-needs-auth-cache.json` and start a new session.
- T3 Code runs Claude with `CLAUDE_CONFIG_DIR=~/.claude`, so folder trust lives in `~/.claude/.claude.json`, not `~/.claude.json`. The `headersHelper` only runs once that file has `hasTrustDialogAccepted: true` for the repo.
