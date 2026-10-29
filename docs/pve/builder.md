# Builder

NixOS Incus container on PVE that runs the forge's Forgejo runner. Its size
is `homelab.guest` in `flake.nix`, `terraform/incus.tf` makes it, and the
service is in `modules/services/forgejo-runner`. It keeps no state worth backing up, so a
dead builder is rebuilt from code.

## How jobs run

Jobs with `runs-on: nix` run straight on the host, not in containers, so the
Nix store stays warm between runs. Whatever a job leaves behind stays too.

- Write temp files with `mktemp` or `$TMPDIR`, not `/tmp`. The runner's
  private `/tmp` is a small tmpfs that only clears on restart, and a few test
  databases once used up its inodes and failed every job. `$TMPDIR` is on
  disk and emptied daily.
- A tool a job needs goes in `hostPackages`, or comes from `nix shell` in the
  job. nix-ld lets generic Linux binaries a job downloads, like the `ruff`
  that `uv sync` installs, run unpatched. Without it they fail with
  `Could not start dynamically linked executable`.
- This bullet is `build.yml` from `shane/workflows` v1.7.0
  ([workflows#19](https://git.shaneplunkett.com/shane/workflows/pulls/19)),
  and until Renovate moves caboodle's pin there from v1.6.1, the `hosts`
  job still evaluates base and head side by side with no cache. An
  evaluation of every host's `hydraJobs` peaks around 14 GB. A pull
  request's `hosts` job evaluates its head once and compares it with the
  mapping `main` left for the merge base, in
  `/var/lib/forgejo-runner/builder/evals/<repo>/<sha>.json`. Each push to
  `main` evaluates once to write that file, and a mapping no job has
  touched in 30 days is deleted. If the merge base has no mapping, the job
  evaluates it too, one after the other, never side by side. A `flock`
  keeps it to one full evaluation on the box at a time, since Forgejo
  ignores `concurrency` on a job.
- The runner is capped at 32 GB. That holds one full evaluation with room
  for the per-host build jobs beside it, or the pair the v1.6.1 pin still
  runs side by side. Builds happen in nix-daemon, outside the cap, and the
  16 GB left is theirs and the OS's. Past the cap the kernel kills the
  biggest process in the runner, almost always an evaluation. The wedge
  test showed that kill. `OOMPolicy=continue` stops systemd taking the
  whole runner down over it, so the expected outcome is that the killed
  evaluation's job fails and the others carry on. That isn't a promise: if
  several evaluations grow at once, the kernel can kill again, in another
  job. Re-run whatever failed once the rest finish.
- If the runner thrashes below its cap instead, systemd-oomd kills it
  whole once its memory pressure stays over 50% for 20 seconds. Every job
  it had running fails with a lost runner, and systemd restarts it. Re-run
  those jobs, deploys included. That's the second line, and unproven as
  set up here: the test only saw oomd fire under a `MemoryHigh` throttle,
  which the runner doesn't set. Hitting the cap alone leaves the pressure
  near 0, so the kernel kill comes first. oomd used to watch
  `system.slice` instead, which never fired: "full" pressure means every
  task in the cgroup is stalled at once, and while the runner's own
  evaluations stalled, other services kept the slice at 15%. Twice in one
  day the box went unreachable with nothing killed, until an
  `incus restart builder` or a manual kill.
- The runner isn't a trusted Nix user, so a flake can't add caches for
  itself. The builder trusts the workstations' caches instead, or a desktop
  build would compile noctalia from source.

## Deploying

Every push to `main` deploys the hosts tagged `deploy-on-merge`. Deploys
queue rather than cancel each other. The hosts don't use Tailscale's DNS, so
the builder reaches each one by its LAN address from the hive.

The builder deploys first, on its own. Its SSH config and known hosts come
from the hive, so a host added in the same push can't be reached until the
builder has switched. Deployed alongside the rest, it lost that race and the
new host failed its first deploy. It isn't tagged `deploy-on-merge`, so it
switches once per deploy.

dns2 deploys in a later job, once dns1 answers. Deploying both at once
restarted Blocky on both and left the network without DNS, so a bad DNS
change now only takes one of them down.

The builder deploys itself, from a job on its own runner, and a plain
restart of the runner would deadlock: the switch waits on the restart, the
restart waits on the deploy job, and the job waits on the switch. So a change
reloads the runner instead, and the reload schedules a graceful restart a few
seconds later, which lets running jobs finish first. A job that ends in
`RUN signal: terminated` outlasted the stop timeout.

That graceful restart is also why the builder can't switch twice in one
deploy. Every switch restarts `sysinit-reactivation.target`, and while the
runner is stopping, that restart waits for the stop, which waits for the
deploy job, which waits for the switch. New units queue behind it too, so SSH
stops answering, and only `incus restart builder` on PVE clears it. A second
switch looked free while the config was unchanged, until a systemd bump made the
first switch reload the runner.

## Pull requests

Every pull request gets its derivation diff as a comment from `forge-bot`,
edited on each push, and builds only the hosts in it. An unchanged host is
the derivation `main` already built, so building it again proves nothing.
The `hosts` job does the comparison, so it's the required check, and when
no host changes the one build job is a placeholder whose steps skip,
because Forgejo leaves a job with an empty matrix blocked for good. The
`build.yml` section of `shane/workflows`' README has the details.

`main` won't merge a pull request that's behind it. Use Update Branch's
rebase option, since the button merges `main` in by default, or rebase it
yourself. A behind branch's diff is against an older `main`, so it can miss
what another merge changed. Once it's up to date, its merge base is `main`,
and the diff is exactly what merging changes. Every merge makes the other
open pull requests stale, so each one rebuilds after its update. Renovate
rebases its own the next time it runs.

## Building by hand

`nix build --store ssh-ng://root@builder <flake attr>` evaluates here and
builds there, and is the way to try one host or package before filing.

- **Fetch a result through the cache, never over SSH.** The builder signs
  nothing when it builds; Harmonia signs each path as it serves it. So the
  path sits unsigned in the builder's store, `nix copy --from
  ssh-ng://root@builder` hands over that unsigned copy, and a workstation
  refuses it with `lacks a signature by a trusted key`. The same path from
  `nix copy --from https://cache.shaneplunkett.com <path>` arrives signed
  by the key every workstation already trusts.
- **An overlay package needs `--eval-store auto`.** The repo's own packages
  are overlays with no flake output, so building one means `--impure
  --expr` with `builtins.getFlake`. That route serves the inputs from the
  local fetcher cache without copying them to a remote eval store, and the
  build dies with `path '/nix/store/...-nixos-...' is not valid`. Adding
  `--eval-store auto` evaluates against the local store and ships only the
  derivation closure to the builder.
- **A by-hand build has no root on the builder**, so it lasts until the next
  weekly collection or `min-free` sweep. Fetch what you want to keep.

## Terraform

A pull request that touches `terraform/` gets its plan as a comment. Run
workflow from the Actions tab only plans, which makes a quick drift check.

On `main`, Terraform applies before any host deploys, because a container
change like its memory can restart it and drop colmena's SSH mid-deploy. If
the apply fails, nothing deploys.

Everything is one state on purpose. `backup_hosts` makes a Storage Box
subaccount and an R2 bucket, and the hive's addresses feed both the
containers and their UniFi reservations, so split states would pass
outputs between each other. If an outage keeps blocking applies, split
Cloudflare out first, since it shares the least.

State is in Terraform Cloud. The tokens are agenix secrets the runner loads
as credentials. Two have other names in Bitwarden: `homelab_tfc_token` and
`homelab_hcloud_token`. Terraform reaches Incus with its own client
certificate ([incus](../../modules/services/incus/README.md#terraforms-access)).

A changed secret restarts the runner the same graceful way. Its restart
triggers hash the `.age` files, because their paths sit in the flake's
source, which changes every commit. That restart lands after the first
apply, so a push that changes `modules/agenix/terraform-*.age` applies again
in `terraform-secrets`. If that job fails because it ran on the old runner,
re-run it.

## Updates

The weekly flake update calls `flake-update.yml` in `shane/workflows`, and
its README covers how it works. It runs Friday night so the pull request is
ready to review on Saturday, and it only moves the inputs that aren't pinned
in `flake.nix`. Renovate moves the pinned ones. Its pull request comes from
`forge-bot`, since a pull request can't ask its own author to review.

`scripts/flake-update-notes.sh` adds the changelogs for nixpkgs,
home-manager, nix-darwin and omniwm, and the `flake-update` skill triages
the pull request. Those inputs stay out of Renovate, because a merge on
green would skip the news and new evaluation warnings that only the weekly
pull request shows. A warning doesn't fail a build, so nothing else would
surface it.

`ai-skills` doesn't wait for Friday. Each push to its `main` dispatches
`ai-skills.yml` here with forge-bot's token, which runs the same workflow
with `only: ai-skills` on its own branch and merges once every host builds.
The review happened in `ai-skills`, so a bad skill is fixed by reverting it
there, and the next push carries the revert over.

If another pull request merges while the skills one is still building, the
skills branch falls behind `main`, and Forgejo keeps its scheduled merge but
won't carry it out. It sits open with green checks and an out-of-date
notice. The next `ai-skills` push clears it: the run commits the bump on
current `main`, force-pushes `update/ai-skills`, and refreshes the same
pull request. A push doesn't cancel a scheduled merge, so it goes through
once the new head's checks pass. To land it sooner, rebase it with Update
Branch. The weekly update merges by hand, so it only ever needs the Update
Branch.

## Renovate

Renovate runs on the builder every morning as `forge-bot`, for what a flake
update doesn't move: container images in Nix modules, pinned flake inputs,
the dev shell's `npx` packages, and Terraform providers. New pull requests
default to a Sunday batch, and the repo's rules are in `renovate.json`. To
run it now:

```sh
ssh root@builder systemctl start renovate
```

### Flake inputs

Renovate only updates an input whose commit is written into `flake.nix`. One
that's only in `flake.lock` gets nothing of its own. To hand an input to
Renovate, pin it, then run `nix flake lock`:

- `github:owner/repo/<commit>`
- `git+https://github.com/owner/repo?ref=<branch>&rev=<commit>` to follow a
  branch, since `github:` won't take a branch and a commit together.

Pinned inputs merge themselves: Renovate asks Forgejo to merge once the
checks pass. That only works because `main` requires the build check
(`terraform/forge-config.tf`). Without required checks, Forgejo merges on
the first status it sees, pending or failed. The required contexts are globs
over job names, so renaming a CI job, or giving a called workflow a `name:`,
leaves every pull request pending until the contexts follow. `/ hosts` is
required because the per-host builds don't exist until it finishes, and
`/ check*` has its wildcard because Forgejo calls one of the two jobs named
`check` `check-1`. Shane can still merge past a failed check.

`minimumReleaseAge` is off for them, because `git-refs` has no release dates
and the wait would hold every input forever.

Only the fast movers with nothing to review are pinned: `llm-agents` and the
Homebrew taps, which share a pull request. Everything else waits for the
weekly update, and these couldn't go to Renovate anyway:

- nixpkgs, because another input locks its own `nixpkgs` node.
- electron-nixpkgs, which a pin would turn into a clone of nixpkgs.
- The inputs on the forge, which Renovate can't reach without an SSH key.

Moving an input between the two without moving its lock means editing its
`original` in `flake.lock` to match the new URL, adding or dropping the
`rev`. Change only `flake.nix` and `nix flake lock` relocks it at the
latest commit.

### Repos and lock files

- Renovate finds every repo in the `shane` org through
  `autodiscoverNamespaces`. Its default search stopped finding public repos
  once the org went public. A new repo gets an onboarding pull request, and
  closing it unmerged tells Renovate to leave the repo alone.
- It regenerates lock files with the tools in `runtimePackages`. A repo
  whose package manager isn't there gets an "Artifact update problem"
  comment with an empty error, so add the tool.
- `renovate-github-token` is a read-only GitHub token, because GitHub won't
  list tags and releases without one.

## Registration

The forge and the builder share the `forgejo-runner-secret` secret, 40 hex
characters. `forgejo-runner-register` on the forge registers the runner with
it on every boot, which is idempotent. The first 16 characters identify the
runner, and its UUID in the Nix module is those characters' bytes as hex.

To replace the secret, from `modules/agenix`:

```sh
head -c 20 /dev/urandom | od -An -tx1 | tr -d ' \n' | rbw edit forgejo-runner-secret
printf '%s' "$(rbw get forgejo-runner-secret)" | agenix -e forgejo-runner-secret.age
printf '%s' "$(rbw get forgejo-runner-secret | head -c 16)" | od -An -tx1 | tr -d ' \n' \
  | sed -E 's/(.{8})(.{4})(.{4})(.{4})(.{12})/\1-\2-\3-\4-\5/'
```

The last command prints the new UUID for the module. Deploy the forge, then
the builder.

## Binary cache

Harmonia serves the builder's own store at `cache.shaneplunkett.com`, so
anything a job builds can be downloaded instead of built again. Nothing is
pushed to it: building something is what caches it. The name only resolves
through Blocky, so the cache is reachable on the LAN and the tailnet and
nowhere else. A machine trusts it by the public half of
`nix-cache-signing-key`:

```sh
rbw get nix-cache-signing-key | nix key convert-secret-to-public
```

A build only stays cached while something roots it, because the store is
collected weekly and whenever free space drops below `min-free`. Jobs root
a build with `--out-link` into the runner's state directory. The builder's
disk alert is worked out from `min-free` in `hosts/builder.nix`, set 5 GiB
past it, so Discord only hears about a full disk when collection can't keep
up.

The build workflow also runs on pushes to `main` only to root each host's
latest build, so the desktop and MacBook stay cached until they're switched.

## Darwin builds

The builder hands `aarch64-darwin` builds to the mini over SSH, as `shane`
with `builder-ssh-key`, and the results come back into its store and the
cache. The mini's address is fixed in `darwin-builder.nix`, so if darwin
builds stop connecting, check its DHCP reservation first.

## Fetching other repos

The forge needs a sign-in to see anything, and a job's own token only reaches
the repo it's running for. So flake inputs from other forge repos, like
`vex-brain`, come over SSH with the builder's own key, `builder-ssh-key`. It's
added to each repo the builder fetches as a read-only deploy key. To print
the public half for a new repo:

```sh
ssh root@builder ssh-keygen -y -f /run/agenix/builder-ssh-key
```

## Gotchas

- **Testing the memory backstop.** Run one evaluation as a transient unit
  under a small cap and watch it from a second SSH session, never through
  the runner. Copy a checkout into a `mktemp -d` on the builder first, and
  only start with more than 30 GB free:

  ```sh
  systemd-run --unit wedge-test -p MemoryMax=6G \
    -p ManagedOOMMemoryPressure=kill -p ManagedOOMMemoryPressureLimit=50% \
    -p ManagedOOMMemoryPressureDurationSec=20s -p CPUQuota=400% \
    -p RuntimeMaxSec=900 --wait --collect \
    nix eval --no-eval-cache --json "path:$dir#hydraJobs" \
    --apply 'jobs: builtins.mapAttrs (_: job: job.drvPath) jobs'
  ```

  On 28 October the kernel killed it 45 seconds in, as it reached 6 GB.
  Its memory pressure never left 0, so oomd had nothing to act on, and SSH
  and PVE's load were unaffected. To see oomd fire, add `-p MemoryHigh=4G`
  and raise `MemoryMax` to 8G. The kernel then throttles the evaluation
  instead of killing it, its pressure climbs past 50% within a minute, and
  `journalctl -u systemd-oomd` logs it being marked for killing 20 seconds
  later. Without `--no-eval-cache`, a revision the builder has already
  evaluated comes from the cache and proves nothing.

- **`rbw add` and `rbw edit` read from stdin** when it isn't a terminal, and
  only the first line becomes the password. A multi-line value like an SSH
  key can't live in Bitwarden that way, so `builder-ssh-key` exists only in
  agenix. If it's lost, make a new one and replace the deploy keys.
- **Registering without `--keep-labels` wipes the runner's labels.**
  `forgejo-runner-register` re-runs whenever Forgejo restarts, and the
  runner only declares its labels when it starts itself. Without the flag,
  every forge restart left the runner online with no labels, and jobs waited
  for a runner with `nix` that never came.
