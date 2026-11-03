# Merges deploy from a runner at home

A merge to `main` deploys, and CI still only checks. One self-hosted GitHub
runner guest on PVE, the runner, builds every Linux host, pushes the
closures to the cache, applies the servers and runs Terraform. A second,
build-only runner on the mini pushes the darwin hosts. The cache is
Harmonia over a guest's store that both runners push into with `nix copy`
over SSH, and every host pulls from it. The desktop keeps
`scripts/deploy.sh` as the fallback for when the runner is down, and the
hand-switched hosts stay hand-switched, with their closures already built.

0004 made the desktop the only place that builds and deploys, because the
October pipeline had become a job to run. That fixed the pipeline and
brought back the things it had been built to remove: nothing deploys until
someone runs a script, nobody knows which commit a host is on without
asking it, and a flake bump lands unbuilt. The check also took seven
minutes, of which eleven seconds were checking and the rest compiling the
unfree terraform binary that cache.nixos.org refuses to carry. A runner at
home gives the merge back its meaning. The builder it replaces failed for
reasons that were design choices, not the idea: two full-hive evaluations
per pull request, four jobs at once with no memory cap and no swap, Renovate
rebasing every open pull request in a burst, and a box that deployed itself
and served its own store to everyone.

Three rules keep the runner from becoming the builder again.

- **One job.** The runner runs `deploy.yml` on a push to `main` and nothing
  else. Checks and Renovate stay on GitHub's runners, so a merge is never
  blocked by the homelab being down. One registration takes one job at a
  time, and `concurrency: deploy` queues the rest without cancelling. Pull
  requests never build or diff.
- **Skinny roles.** The runner holds exactly what the deploy needs, all from
  agenix: the inputs token for the private flake inputs, the Terraform
  tokens and Incus key, the App's private key to register itself, and a
  root SSH key for the guests it applies and the cache. It serves nothing,
  it is not in `@deploy`, and the desktop deploys it.
- **Nukeable.** Nothing depends on the runner but the next deploy. Its store
  is not the cache, its key signs nothing anyone trusts, and
  `incus delete runner` followed by a deploy from the desktop loses
  nothing. The same test applies to the mini's runner, which runs as its
  own user with only the inputs token and a key to the cache.

The guest is sized for one evaluation with room: 32 GB and 8 cores, at the
bottom of Incus's CPU and disk priority, with `scripts/quietly.sh`'s
`MemoryMax` a few GB under the guest's limit so a runaway evaluation is
killed rather than thrashed. PVE has 93 GB and has not dropped below 38 GB
free in a week.

The cache is a shelf, not a service. Harmonia has no database, no tokens
and no uploads; it signs and serves what is in the store under it. The
runners push with `nix copy --to ssh-ng://cache` as root, and each push
sets a profile per host, so Nix's own garbage collection keeps the last
generations and nothing else needs a retention policy. Pulls have no
authentication and the name only resolves on the LAN and the tailnet. The
cost is disk, since `nix copy` ships whole closures and there is no
upstream filter; the guest's disk lives on PVE's second NVMe, which has
room. Attic was justified on 31 October by GitHub-hosted runners pushing
over HTTP from outside the LAN, and that pusher no longer exists.

The desktop-to-Deck and mini-to-MacBook `ssh-ng` store sharing from 0004
goes, since every host pulls from the cache instead, and
`system.configurationRevision` on every host answers which commit it runs.

## Considered options

- **The desktop deploys on a timer**, polling `origin/main` and running
  `scripts/deploy.sh`. No new guest and no new keys, but nothing deploys
  until Shane is logged in at the desktop, and the run is invisible from
  GitHub.
- **Several small runners** with per-host evaluation. That is 0003's matrix
  and baseline mapping, which only existed because hosted runners have
  16 GB. Owning the RAM removes the reason, and each extra runner is a cold
  store compiling the Sunday bump again.
- **The runner's store served as the cache**, with `nix.sshServe` as the
  desktop does for the Deck today. Zero new parts, and the builder's
  coupling back: the cache's contents become whatever the runner has not
  garbage collected, every switch depends on the runner being up, and the
  signing key sits on the box that runs jobs.
- **Attic**, on local disk or R2. HTTP push with tokens, a database, a JWT
  key, chunking and a gotcha list, for a pusher that is now two LAN
  machines with SSH keys. R2 adds a Cloudflare token and a round trip per
  path to buy off-tailnet pulls nobody needs.
- **Atelier** (`stepbrobd/atelier`), which fans out one hosted build job per
  derivation. Its Discover job is pinned to `ubuntu-latest` and evaluates
  with `github.token`, which cannot read the five private inputs, so it
  fails before any build; and its fan-out is only worth having on hosted
  runners, where the self-hosted design is the opposite shape on purpose.
- **Pull-based deploys**, each guest fetching its own closure. It inverts
  the keys, but each guest then needs a signal that a closure is ready and
  a place to fetch it from, which is a cache plus a protocol, to avoid a
  root key the desktop already holds.
- **Gating the deploy behind a GitHub environment**, so a merge waits for a
  click. That is the manual deploy with a different hat; timing is chosen
  by choosing when to merge, and `docs/**` is ignored so a docs merge costs
  no evaluation.
- **A fine-grained PAT** to register the runner instead of the App. No
  script, but it expires, nothing alerts, and the failure lands at the next
  re-registration, which is the next time the runner's config changes.

## Consequences

- A failed deploy is a red cross on the commit and an email from GitHub.
  Shane wants it in Linear's inbox without an issue being filed, and that
  is open; so is moving Alertmanager off Discord.
- `scripts/deploy.sh` from the desktop and the runner have no lock between
  them. The desktop path is for when the runner is down, which is when they
  cannot collide.
- A Terraform-only merge still evaluates the hive, a few wasted minutes
  rather than a second code path.
- The check caches the terraform derivation in GitHub's Actions cache from
  the shared `check.yml`, which action to be confirmed on a private repo
  before it is filed.

This supersedes 0004, which was deleted once this landed;
`git log --diff-filter=D -- docs/adr` finds it.
