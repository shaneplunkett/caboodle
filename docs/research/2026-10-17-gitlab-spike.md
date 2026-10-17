# GitLab spike

- **Question:** Does self-hosted GitLab CE work with Linear, CodeRabbit, T3
  Code and the runner design in [the plan](../prd/forge-and-builder.md), and
  what has to be reachable from the internet?
- **Researched:** 2026-10-17, against GitLab CE 19.5.0.

GitLab ran in Docker on the desktop, capped at 4GB of RAM, with a GitLab
runner using the Docker executor. Outside services reached it through a
Cloudflare quick tunnel and a Caddy proxy that logged every request. The web
UI stayed on `localhost`. GitLab used 2.6GB after first boot, with Puma in
single mode, Sidekiq at 10 threads and its bundled Prometheus off. The
scripts lived in `~/Projects/personal/gitlab-spike`, outside the repo.

## Linear: tested

- MRs link both ways. Linear posts a link-back comment as the token's owner,
  so it gets its own `linear-bot` user with Reporter on the group.
- Its calls hit `/api/v4/*` and `/api/graphql`, nothing else.
- Every call came from an IP in
  `https://linear.app/.well-known/appspecific/app.linear.ips.json`, which
  Linear updates four weeks before using a new one. A Cloudflare WAF rule
  built from that file locks the tunnel to Linear.
- Group webhooks are Premium, so each project gets its own, from
  Terraform's `gitlab_project_hook`. Use Linear's secret token. GitLab 19
  recommends its HMAC signing token, but Linear can't check one.
- Linear ignores a review request from the MR's own author. Setting "On PR
  open" to In Review moves the issue there when an agent opens the MR.
- The inbox pings. Linear credits the move to GitLab, so the subscribed "My
  issues in review" view notifies Shane even though her own token opened
  the MR.

## CodeRabbit: in principle

Not run. Its self-managed GitLab docs and IP allowlist cover it, but it needs
more than the API: git clone over HTTPS and the OAuth token exchange. Its
sign-in sends the browser to GitLab's public URL, so Blocky should answer that
hostname with the internal address. Onboard it manually, with its own user and
OAuth app, rather than giving it an admin token.

## Runner: tested

- The Docker executor gives every job a clean container.
- A protected, masked group variable reached `main`'s pipeline and not an MR
  branch's, so job secrets stay off MR and Renovate pipelines.
- `nix build` works in `nixos/nix`, starting from an empty store each time.
  The cache box has to make that cheap.
- A pipeline superseded by a newer push shows as `canceled`, grey, on the
  commit as well as the pipeline. Jobs need `interruptible: true` for that.
  Deploy jobs stay uninterruptible and queue with a `resource_group`.
- The MR page updated by itself when the pipeline finished.

## T3 Code: read from the code

GitLab works for the whole loop: opening an MR from a thread, status,
comments, approve, merge, auto-merge, and `watch_pull_request` waking the
agent. The gap that matters is CI, which shows as one "Pipeline" check instead
of one per job. Upstream closed the fix, #13434, for size, so vex-code
cherry-picks it. T3 only recognises a self-hosted GitLab whose hostname
contains `gitlab`, so use `gitlab.shaneplunkett.com`, with the same hostname
for SSH and the web.

## Pocket ID: in principle

Pocket ID documents GitLab as a client, at
https://pocket-id.org/docs/client-examples/gitlab. Gate access with the
client's allowed groups in Pocket ID, because GitLab's OIDC group mapping is
Premium.

## Behind Premium

- The ones that touch this setup: group webhooks, pull mirroring (push
  mirroring is free), and more than one assignee or reviewer per MR.
- Unneeded: Code Owners, approval rules, push rules, merge trains, MR
  dependencies, protected environments, deploy approvals, scoped labels,
  group-level MR templates, epics and OIDC group mapping.
- Free: resource groups, parent-child and multi-project pipelines,
  auto-merge, the container and package registries, fine-grained tokens,
  webhook signing and OIDC sign-in.

## Gotchas

- GitLab 19 makes fine-grained tokens the default, and the UI no longer
  offers the `api` scope. An admin can still make a legacy token through
  `POST /users/:id/personal_access_tokens` with `scopes[]=api`.
- `glab` ignores the scheme in `GITLAB_HOST`. For plain HTTP, set
  `API_PROTOCOL=http`.
