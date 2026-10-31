# GitHub with hosted runners, and no builder

GitHub is the primary forge, GitHub-hosted runners evaluate, build and
deploy, and the builder guest goes. Forgejo's integration upkeep had grown
past what it saved, and one persistent box holding the deploy keys, the
Terraform tokens and a warm store that every job could read was the shape
Shane wanted rid of. Hosted runners are disposable by nature and free on a
public repo, so the isolation the CI notes asked for comes with the move
instead of being built. A cache at home (Attic) and a cold git mirror at
home are what stays on Shane's hardware. The evaluate-once rule and the
block on outdated branches from ADR 0002 still hold; its choice to keep
Forgejo and the builder is superseded by this record.

The costs: every build job pushes to the cache before it dies, because the
runner's store is gone when the job ends; deploys reach the LAN through
Tailscale from a job, which the forge's runner never needed; and a cold
rebuild of the biggest closure runs on a 4-vCPU box, so slower than the
builder. The derivation diff is evaluated per host in a matrix, because a
single evaluation of the hive at 14 GB has no headroom on a 16 GB runner.

## Considered options

- **GitHub's runner software on the builder, as today with Forgejo's.**
  Smallest change, and every builder gotcha carries over unchanged: the
  self-deploy deadlock, the eval lock, the memory cap, and a PR job that
  can read the deploy credentials.
- **Self-managed GitLab.** Merged-results pipelines need Premium, and it
  would run on the same machines with the same one-box problem.
- **Hosted Nix CI.** garnix shut down on 15 July 2026, Hercules CI runs
  its agent on a machine you own, and nixbuild.net sells build hours
  without a cache. The [31 October research](../research/2026-10-31-nix-ci-on-github-hosted-runners.md)
  has the dates.
- **A warm Forgejo kept as a pull mirror.** The same upkeep for a UI
  nobody opens. The mirror is bare clones on a timer instead.
