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

On 1 November 2026 Shane replaced Atelier, the plan's first choice for
building, with builds in the diff's own per-host jobs. Atelier evaluates
every host again in its build jobs, and its secrets and permissions can't
carry the private inputs, the tailnet join or a private cache, so the
evaluate-once rule and the private cache would both have had to give. The
cost is that the diff comment waits for the builds.

The choice is made; the migration has not happened. Until cutover, changes
still go through Forgejo and its runner, and the [forge](../pve/forge.md)
and [builder](../pve/builder.md) docs describe what runs today.

## The shape

**On a pull request:**

1. workflows' `hosts.yml` evaluates each host in its own matrix job, once,
   and compares it with the mapping `main` uploaded as an artifact for the
   merge base. If the merge base has none, a matrix of its own evaluates it
   first. The hive is never evaluated in one process: that peaked at 14 GB
   on the builder and a hosted runner has 16 GB.
2. The same job then builds its host if it changed, from the derivation it
   just evaluated, and pushes the closure to the cache, so nothing is
   evaluated twice. A rerun builds again, but with the closure cached that
   only fetches. Darwin hosts evaluate and build on hosted macOS runners,
   which have about 94 GiB free rather than the documented 14 GB, so the
   mini doesn't register as a runner, and nothing at home runs jobs.
3. A `hosts` job gathers them all and posts the derivation diff as a
   comment, after the slowest build, with what built and what failed. It
   is the required check, and fails on a failed evaluation, build or push.
4. A Terraform plan comment when `terraform/`, `flake.nix` or
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
SQLite, from nixpkgs' `services.atticd`. It is reachable only on the LAN
and the tailnet, as Harmonia's was: `cache.shaneplunkett.com` resolves
through Blocky and nowhere else, there is no Cloudflare record and no
route in from the internet. Closures carry builds of the private repos, so
the cache is never public; pulls need a pull token too, one agenix secret
every host reads. Hosts and the desktop pull by the Blocky name over the
LAN. A hosted runner pulls and pushes over the tailnet, by the guest's
tailnet name, which it joins anyway. The cache's upstream filter keeps
paths cache.nixos.org already has out of it. Garbage collection is
retention per cache. Nothing backs it up: a lost cache is a slow week.

**Tailscale** is joined from the job with workflows' `tailnet` action,
which pins `tailscale/github-action`, as an ephemeral node tagged `tag:ci`,
using workload identity federation: a federated identity in Tailscale
trusts GitHub's OIDC issuer for this repo and grants `auth_keys` for the
tag, so GitHub holds a client id and an audience and no Tailscale secret.
The identity has no name; it's client id
`TFs2XEmZQ321CNTRL-krgzEHAvjw11CNTRL`, audience
`api.tailscale.com/TFs2XEmZQ321CNTRL-krgzEHAvjw11CNTRL`, in the repository
variables `TAILSCALE_CLIENT_ID` and `TAILSCALE_AUDIENCE`. Its subject is
`repo:shaneplunkett@113661103/caboodle@1175054018:*`, because the repo uses
GitHub's immutable subjects, with the account and repo ids in; the
name-only `repo:shaneplunkett/caboodle:*` never matches. Two grants let
`tag:ci` reach `tag:homelab` on 22 and the cache's tailnet address on
8080. Grants only add access, so the default allow-all grant's source is
narrowed to `autogroup:member` and `tag:homelab`; left as `*`, it would
let `tag:ci` reach everything. What a job may do is decided by which
GitHub Environment it runs in, not by a second tag.

**Identity** is one GitHub App installed on Shane's account. It posts the
diff and plan comments, opens the flake update pull requests so Shane can
review them, runs Renovate from a scheduled workflow, dispatches the
`ai-skills` bump into this repo, and fetches for the mirror. Its tokens
last an hour and are minted in the job from `APP_CLIENT_ID` and
`APP_PRIVATE_KEY` (`github-app-client-id` and `github-app-private-key` in
Bitwarden). The six inputs on the forge move to `github:` URLs; the runner
and the workstations read the private ones with a read-only fine-grained
token in `access-tokens`, `INPUTS_TOKEN` (`github-inputs-token`). The
[builder doc](../pve/builder.md#github-app-and-inputs-token) has their
permissions and how to renew the token.

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
2. **Cache.** Add the `cache` guest and its Attic, the Blocky answer, the
   push and pull tokens in agenix, and the workstations' substituter. No
   Cloudflare record: the name stays LAN and tailnet only. Seed it from the
   builder's store.
3. **Build and push.** Build the changed hosts in the diff's own jobs,
   pushing to the cache from pull request jobs and pushes to `main`. Run both CIs for a few real changes,
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
