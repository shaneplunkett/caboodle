# Moving back to GitHub

## Decision, 31 October 2026

GitHub is the primary forge, GitHub-hosted runners do the evaluating,
building and deploying, and the builder guest is retired. What stays at
home is a cache the jobs push to and a cold mirror of every repo.
[ADR 0003](../adr/0003-github-with-hosted-runners-and-no-builder.md) has
the trade-off, and the
[31 October research](../research/2026-10-31-nix-ci-on-github-hosted-runners.md)
the tooling behind it, with dates. The
[GitLab spike](../research/2026-10-17-gitlab-spike.md) stays as research
into the alternative.

The choice is made; the migration has not happened. Until cutover, changes
still go through Forgejo and its runner, and the [forge](../pve/forge.md)
and [builder](../pve/builder.md) docs describe what runs today.

## The shape

**On a pull request:**

1. A `hosts` job of ours evaluates each host's derivation path in its own
   matrix job, gathers them, compares with the mapping `main` uploaded as
   an artifact for the merge base, and posts the derivation diff as a
   comment. It is the required check. If the merge base has no artifact,
   the job evaluates it too. The hive is never evaluated in one process:
   that peaked at 14 GB on the builder and a hosted runner has 16 GB.
2. [Atelier](https://github.com/stepbrobd/atelier), pinned by commit since
   it has no releases, discovers outputs with nix-eval-jobs, builds one
   derivation per job, skips anything a substituter already has, and
   pushes the results to the cache. Darwin hosts build on hosted macOS
   runners. If a closure outgrows their 14 GB disk, the mini registers as
   a darwin-only runner; nothing else at home runs jobs.
3. A Terraform plan comment when `terraform/`, `flake.nix` or
   `modules/devices.nix` changed, as now.

**On a push to `main`:** Terraform applies, then colmena deploys the
`deploy-on-merge` hosts from the runner over the tailnet, dns2 after dns1
answers, hosts fetching the closure from the cache on the LAN. The
builder-first step goes with the builder. The deploy job alone holds the
SSH key, the Terraform Cloud token, the Incus client certificate and the
UniFi credentials, in a `deploy` Environment that only `main` can use. A
pull request job holds the inputs token and a push token for the cache,
and nothing else. A pull request from a fork gets no secrets at all.

**The cache** is Attic on a `cache` guest on PVE, chunks on local disk,
SQLite, from nixpkgs' `services.atticd`. `cache.shaneplunkett.com` is
proxied through Cloudflare for pulls, which caches the NARs at the edge,
and Blocky still answers it locally so hosts pull over the LAN. Pushes go
over Tailscale, which sidesteps Attic's one-request-per-path upload and
Cloudflare's 100 MB body cap. The cache's upstream filter keeps paths
cache.nixos.org already has out of it. Garbage collection is retention
per cache. Nothing backs it up: a lost cache is a slow week.

**Tailscale** is joined from the job with `tailscale/github-action`, as an
ephemeral node tagged `tag:ci`, using workload identity federation: a
federated identity in Tailscale trusts GitHub's OIDC issuer for this repo
and grants `auth_keys` for the tag, so GitHub holds a client id and an
audience and no Tailscale secret. One ACL rule lets `tag:ci` reach every
host on 22 and the cache on 443. What a job may do is decided by which
GitHub Environment it runs in, not by a second tag.

**Identity** is one GitHub App installed on Shane's account. It posts the
diff and plan comments, opens the flake update pull requests so Shane can
review them, runs Renovate from a scheduled workflow, dispatches the
`ai-skills` bump into this repo, and fetches for the mirror. Its tokens
last an hour and are minted in the job. The six inputs on the forge move
to `github:` URLs; the runner and the workstations read the private ones
with a read-only fine-grained token in `access-tokens`.

**The mirror** is a `mirror` guest on PVE with a bare clone of every repo
on the account under the NAS pool, refreshed by a short script on a timer
that mints an App token, lists the installation's repos, clones new ones
and updates the rest. restic backs the folder up. Forgejo's pull requests
and issues get one API dump onto the pool before the forge goes.

**`shane/workflows`** becomes a public `shaneplunkett/workflows` carrying
the diff job and the callers' shared pieces; `actions/checkout` replaces
its checkout action. caboodle stays public, which is what makes rulesets,
strict up-to-date checks, Environments and uncapped runner time free. The
private repos have no required checks today and keep none, so no paid plan.

## Work before cutover

GitHub already holds a copy of this repo that Forgejo pushes to on every
commit, so the new pipeline is built beside the old one and proven on real
pushes before it holds any deploy rights.

1. **Measure.** One PR adds the `hosts` matrix and a disk-reclaim step for
   the runner, and records peak memory for the fattest hosts (the desktop
   and the dashboard read other hosts' configuration). Nobody publishes a
   per-host figure, so this is the first thing we learn.
2. **Cache.** Add the `cache` guest and its Attic, the Cloudflare record,
   the Blocky answer, the push token in agenix, and the workstations'
   substituter. Seed it from the builder's store with `nix copy`.
3. **Build and push.** Add Atelier with its diff job beside it, pushing to
   the cache from pull request jobs. Run both CIs for a few real changes,
   including a nixpkgs bump, until the GitHub diff matches Forgejo's every
   time and the cache is warm.
4. **Identity and integrations.** Create the App, install it, port Renovate
   and the two flake update workflows to run as it, move the `ai-skills`
   dispatch, switch the six inputs to `github:` URLs, and point Linear,
   CodeRabbit and T3 at the GitHub repos.
5. **Mirror.** Add the `mirror` guest and its timer, and take the Forgejo
   metadata dump.
6. **Tailscale.** Create the federated identity and the `tag:ci` rule, and
   prove a job can reach the cache and SSH to one host.

## Cutover

One pull request: the `deploy` Environment and its secrets, the deploy
workflow, the `main` ruleset with `hosts` required and strict, and the
remote and skill changes. Then Forgejo's push to GitHub stops, the mirror
takes its first fetch from GitHub, and the forge's runner is disabled so
one merge cannot deploy twice. Prove the path from a GitHub pull request
through checks, review, merge and deployment.

## After

The builder and forge guests, their Terraform (including
`forge-config.tf` and the Forgejo provider), their secrets, the forge's
Pocket ID client, `ForgejoWorkflowFailing` and the `tea` skill all go.
There is no fallback box: the worst case after cutover is a cold rebuild,
which took the Deck 45 minutes on the builder and will take longer on a
4-vCPU runner, well inside the six-hour job limit.

The `ai-skills` pull request still strands behind `main` when another
merge lands while it builds. GitHub's auto-merge has the same rule as
Forgejo's, so the fix is the one the [CI notes](ci-redesign.md) named: a
step on each push to `main` that updates the open auto-merge pull
requests.
