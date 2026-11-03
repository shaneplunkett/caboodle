# Runner

Incus guest on PVE that runs GitHub Actions jobs for caboodle, one at a time.
The service is `modules/services/github-runner`, and
[ADR 0005](../adr/0005-merges-deploy-from-a-runner-at-home.md) has the why.
It runs [the deploy job](#the-deploy-job), and
`.github/workflows/runner-smoke.yml` proves the guest works. Run workflow on
the smoke test's Actions page prints the hostname and the job's memory cap,
then builds `hello` through `scripts/quietly.sh`.

## The three rules

- **One job.** One registration takes one job, so a second dispatch waits in
  GitHub's queue. Checks and Renovate stay on GitHub's runners.
- **Skinny roles.** It holds what the deploy needs and nothing more, from
  agenix. It serves nothing: no `sshServe`, no signing key, no routes. It isn't
  in the `deploy` tag, so `scripts/deploy.sh runner` from the desktop is the
  only thing that deploys it.
- **Nukeable.** Nothing but the next deploy depends on it. See
  [Nuking it](#nuking-it).

## Registration

The runner registers with the GitHub App, not a personal token. Before
`github-runner-homelab.service` starts, `github-runner-registration.service`
fills `/run/github-runner-registration/token`, a root-only file on tmpfs:

1. A runner with credentials in `/var/lib/github-runner/homelab` gets its
   module's own `.current-token` copied back. No call to GitHub.
2. A runner without them signs a JWT with the App's key, mints an installation
   token narrowed to caboodle and `administration: write`, and asks for a
   registration token.

The copy in step 1 exists because the NixOS module wipes the runner's state and
registers again whenever the token file differs from `.current-token`. Minting
on every start would register on every start. The oneshot is its own unit so
that `LoadCredential` never hands the App's key to the runner's service, where
every job could read it.

The copy runs as root and reads from a directory the job's user owns, which is
only safe because of the module's `InaccessiblePaths`. It mounts over
`.current-token` in the job's view, and the kernel refuses to unlink or replace a
mount point, so a job can't swap it for a symlink to one of root's files. If a
symlink ever turns up anyway, the oneshot mints instead of following it.

**The App needs Administration write.** GitHub lists
`POST /repos/{owner}/{repo}/actions/runners/registration-token` under
"Repository permissions for Administration" in
[Permissions required for GitHub Apps](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps).
Without it the token request fails with a 422, "The permissions requested are
not granted to this installation", and the runner never starts. In the App's
settings on GitHub, set Repository permissions > Administration to Read and
write, then accept the new permission on the installation under Settings >
Applications.

That grant covers every repo the App is installed on, and any token minted
without narrowing inherits it, so
[the other mints narrow](../github/README.md#github-app-and-inputs-token).
Anyone with the private key can still mint one that doesn't.

## The guard

caboodle is public, so a workflow asking for `runs-on: [self-hosted, homelab]` can
come from any pushed branch, or from a fork's pull request once GitHub's contributor
approval lets it run. This runner holds [the deploy key, the inputs token and the
Terraform secrets](#what-it-holds), so it refuses every job unless `GITHUB_REPOSITORY`
is exactly `shaneplunkett/caboodle` and `GITHUB_REF` is exactly `refs/heads/main`.
Anything missing, empty or different is refused. The
[mini's runner](../mini/README.md#the-guard) runs the same script.

`modules/services/github-runner/job-started.sh` is the runner's job-started hook,
which the service names in `ACTIONS_RUNNER_HOOK_JOB_STARTED`. It runs first in every
job, in a step called `Set up runner`. A refused job goes red with `Job refused` in
that step and on the run's page, and every step after it is skipped. The run also
shows "The runner has received a shutdown signal". That's the hook's doing,
and the listener carries on and takes the next job. `job-started-test.sh` runs in
`scripts/check.sh`.

**Failing the hook isn't enough.** GitHub's docs say the job won't run if the hook
exits non-zero, but the runner's `JobExtension.cs` and `StepsRunner.cs` say otherwise.
The hook is one step in the job's list. Its failure fails the job and the runner keeps
walking the list, so a step with `if: always()` still runs, with everything this runner
holds. So the hook stops the worker instead. SIGTERM makes `Runner.Worker` shut down,
and during a shutdown the runner skips every remaining step without evaluating its
condition. A worker still there after 30 seconds gets SIGKILL.

What a job can't change:

- **The values.** The runner starts a hook with an empty step environment and sets
  `GITHUB_*` from the job's `github` context, which comes from GitHub. A workflow's
  `env:` never reaches the hook, so neither do `GITHUB_REF`, `BASH_ENV` or `PATH`. No
  step has run yet, so nothing has touched `GITHUB_ENV`.
- **The hook.** The script is in the store, and systemd sets the variable. The one way
  round that is `.env`: the listener reads `$RUNNER_ROOT/.env` when it starts, and that
  file beats the service's environment. The job's user owns that directory, so the
  service removes the file before every start.
- **The repository.** This runner is registered on caboodle alone, so GitHub never
  sends it another repo's job, whatever else the App is installed on. The check on
  `GITHUB_REPOSITORY` is a second lock.

The limits:

- **`main` is the boundary, and it has no review rule.** Its ruleset wants a green
  check, so anyone who can push can land a workflow on `main` and it runs with all of
  the above. The guard stops unmerged code, not merged code.
- **Some events read as `main` whoever caused them.** `pull_request_target`,
  `workflow_run`, `issue_comment` and `schedule` all have `GITHUB_REF` on the default
  branch, with the workflow file from there too. A workflow on one of these that checked
  out a pull request's code would pass the guard, so none of them belongs on this
  runner. Re-running an old run on `main` passes as well.
- **The runner fetches actions first.** It downloads and reads a job's `uses:` actions
  before the hook, and none of their code runs. They sit in the work directory until the
  next start empties it.
- **Refused jobs still take the runner.** One takes a few seconds, but a fork's pull
  requests can queue enough of them to hold up a deploy.
- **An allowed job can rewrite the runner.** `.env` isn't the only file in the state
  directory the listener reads at start: `.runner` and `.credentials*` are there too,
  the job's user owns them, and nothing removes them. A job that runs, so one from
  `main`, can change where the runner registers or what it registers with, and that
  survives a restart. The guard is for unmerged code; after a bad merge, the recovery
  is the [nuke](#nuking-it) and a fresh registration.
- **It leans on how the runner behaves.** A runner bump could change what SIGTERM does
  or what a hook sees, and the test here can't tell. Run
  [Proving the guard](#proving-the-guard) when the runner's version moves.

### Proving the guard

This proves the worker's side, which only a real job can. Do it after the runner and
the mini have both deployed the hook. The steps only echo, so a guard that fails leaks
nothing. On a throwaway branch from `main`, replace
`.github/workflows/runner-smoke.yml` with this:

```yaml
on:
  push:
    branches: [guard-test]
  workflow_dispatch:

permissions:
  contents: read

jobs:
  homelab:
    runs-on: [self-hosted, homelab]
    timeout-minutes: 5
    steps:
      - run: echo "the guard let this through"
        if: ${{ always() }}
  darwin:
    runs-on: [self-hosted, darwin]
    timeout-minutes: 5
    steps:
      - run: echo "the guard let this through"
        if: ${{ always() }}
```

Then push it, which starts one run, dispatch a second, and read both:

```sh
git switch -c guard-test origin/main
# replace the workflow, then commit it
git push -u origin guard-test
gh workflow run runner-smoke.yml --repo shaneplunkett/caboodle --ref guard-test
gh run list --repo shaneplunkett/caboodle --branch guard-test --workflow runner-smoke.yml
gh run view <id> --repo shaneplunkett/caboodle --json jobs \
  --jq '.jobs[] | {name, conclusion, steps: [.steps[] | {name, conclusion}]}'
gh run view <id> --repo shaneplunkett/caboodle --log | grep -E 'Job refused|let this through'
gh api repos/shaneplunkett/caboodle/actions/runners --jq '.runners[] | {name, status}'
git push origin --delete guard-test
```

Both jobs in both runs should be `failure`, the `echo` step `skipped` or missing, `Job
refused` in the log, and `let this through` nowhere. Both runners should still be
online. Then check `main` still gets through:

```sh
gh workflow run runner-smoke.yml --repo shaneplunkett/caboodle --ref main
```

That run should pass, with `This job is from shaneplunkett/caboodle on refs/heads/main`
under `Set up runner`.

## The deploy job

`.github/workflows/deploy.yml` runs on every push to `main` that touches
anything outside `docs/`. There's no approval step, so choosing when to merge is
choosing when it lands. The workflow holds no secrets, and the Actions secret
store gains none. It has four steps:

1. **Build.** `scripts/build-linux-hosts.sh` builds every Linux host in the hive,
   the hand-switched ones included, so a merge that breaks PVE fails before
   anything switches. It builds one host per call, tries every host, and a failure
   stops the push and the apply. It takes the list from the flake's `linuxHosts`,
   the same filter as `nixosConfigurations` without `incus-base`, which takes
   seconds to evaluate. A tag would be the obvious alternative, but a host's own
   `deployment.tags` replaces whatever the hive's defaults set, and the first-boot
   guard in the README sets it to nothing.
2. **Push.** `scripts/push-to-cache.sh` copies each closure to the
   [cache](cache.md) and moves that host's profile there.
3. **Apply.** `scripts/deploy.sh` applies the `deploy` tag, then dns2 once dns1
   answers, the same as the desktop. Colmena evaluates the hive again but finds
   everything built, so a run costs two evaluations.
4. **Terraform.** If the push changed anything a plan reads,
   `scripts/terraform.sh apply` plans, prints the plan to the log and applies it.
   See [Terraform](#terraform).

The build evaluates in a dry run of its own and then builds from Nix's eval
cache. An evaluator keeps its heap until it exits, so a `nix build` that did both
would hold about 15 GB of the slice's 28 while the compilers ran. The same cache
makes each build inside `push-to-cache.sh` a lookup. It needs a clean tree, which a
checkout always is.

Each host then gets its own `nix build`, because the daemon's worker for a call
holds the goal graph of every derivation in that call until the call ends. One call
over the whole hive would hold every graph beside the compilers. One call per host
holds one graph at a time and hands the memory back between hosts, though a large
host can still need plenty, so the slice's cap stays the backstop. That has three
costs:

- **Less to run at once.** `max-jobs` can only pick from the current host's
  derivations, so a slot can sit idle that a whole-hive call would have filled, and
  a cold run can take longer.
- **A shared failure repeats.** Nix forgets a failed build between calls, so a
  derivation every host needs fails once per host. An expensive one can run the job
  into its timeout, which still stops the push and the apply.
- **A collection can undo the dry run.** A host's `.drv` files have no GC root until
  its turn, so a `min-free` collection before then takes them and that host evaluates
  again, keeping the heap for the length of its build. It costs memory and time, and
  the result is the same.

The runner trusts the same upstream caches as the workstations, from
`modules/workstation/upstream-caches.nix`. Without them it would compile
everything Noctalia's and Numtide's caches already hold. It also trusts
[Nyx](#nyx), which the workstations don't.

The mini is outside it. Its tag is `deploy-mini`, the runner has no key to it,
and the job can't build darwin, so only the desktop applies it. The Macs build on
the mini's own [build-only runner](../mini/README.md#the-runner).

### When it fails

A failure is a red cross on the merge commit and an email from GitHub. Which step
failed says what state things are in:

- **Build.** A host that doesn't evaluate fails in the dry run, before anything
  builds. One that doesn't compile fails its own call, every other host still gets
  its turn, and the end of the step's log names the hosts that failed. Nothing was
  pushed and nothing switched, so the cache and every host stay on the last good
  commit. What did build stays in the store, so a re-run picks up from there.
- **Push.** The hosts before the failure have this commit on the cache, and the
  rest keep their last closure. The apply still runs and the run still goes red.
  The cache is one of the guests the apply deploys, so stopping here would leave
  a broken cache unable to take its own fix, and colmena ships closures to the
  guests itself. A hand-switched host compiles what the cache doesn't have yet.
- **Apply.** Colmena applies every host it can before it exits, and a failure in
  the first apply stops the script before dns2. The cache already has this commit,
  so a hand-switched host can switch to a closure whose guests didn't all land.
- **Terraform.** The apply was attempted first, and may itself have failed, so
  read its result before Terraform's. The log shows how far the plan or apply
  got, and Terraform Cloud keeps whatever it finished, so re-running the job or
  `scripts/terraform.sh apply` from the desktop plans again from there. A
  `terraform-guard` line means the job stopped before applying anything, and
  [Terraform](#terraform) has the way out.

A job that hits its timeout or gets cancelled before the apply never applies. One
cancelled during the apply stops wherever it was, which can leave some guests
switched and the rest not; the next run or `scripts/deploy.sh` from the desktop
finishes the job.
Rollback is a revert pull request. Re-run failed jobs on the newest run is fine,
but re-running an older run applies that older commit over whatever came after
it, and moves every host's profile on the cache back to it until the next merge.
If that run changed anything a plan reads, it applies the older Terraform too.

`concurrency: deploy` never cancels a running deploy, and `queue: max` keeps
every later merge waiting in order instead of GitHub's default of one pending
run, where a third merge would cancel the second. Each queued run applies its
own commit, so a burst of merges lands one after another.

### Terraform

A merge runs a plan when it changes anything a plan reads, and
`scripts/terraform-changed.sh` holds that list: `terraform/`, what evaluating
`.#network` and the Incus base image reads, and the scripts the job plans
through. Terraform [reads the hive](../adr/0001-terraform-reads-the-hive.md), so a
new guest, device or port forward applies on the merge that adds it, and nobody
has to remember to. Most of these merges can't move the plan, like a README under
`modules/` or an `ai-skills` bump, and their plans find nothing. An extra plan is
cheaper than a forgotten apply. `docs/` and anything else off the list run none.

The evaluation forces `pkgs/overlays.nix` and `pkgs/default.nix`, so those count,
but not the packages they name, and not `home/`. With only the listed paths in a
fresh repo, `git add`ed, `.#network` and the image's derivations come out byte for
byte the same. A new file the evaluation needs fails that check with `Path '...'
does not exist in Git repository`, so it's the way to re-check the list after
rewiring the flake.

The script compares the trees of the commits `main` went from
and to, after a shallow fetch of the before commit, since a diff of two trees
needs no history. A rebase merge's several commits and a force push count the same
way, and a change that a later commit in the same push reverts counts as nothing.
When it can't get the before commit, as with a new branch's all-zero SHA, it says
yes. A plan that changes nothing is cheap, and a skipped apply is the mistake this
step exists to stop.

The step runs after a failed apply, for the same reason the apply runs after a
failed push: the fix for a guest that won't switch can be Terraform's, like more
disk. It stays out of a failed build and a cancelled job.

- **The `Plan:` line isn't what it applies.** The line in the pull request comes
  from the desktop before merging. The runner plans again at merge time and applies
  what it finds, so anything that moved in between goes too.
- **It applies everything it finds.** A plan isn't limited to what its merge
  changed, so a change made in Cloudflare's or UniFi's dashboard gets reverted by
  the next merge that plans. That can be a lock file bump that merged itself.
- **A merge can't delete a guest.** `incus_instance.guest` follows `.#network`
  and has no `prevent_destroy`, so a merge that drops a guest from the hive or
  clears its `homelab.guest` plans to delete the container and its disk. The
  [guard](#terraform) refuses that plan, the run goes red, and the deletion
  waits for `scripts/terraform.sh apply` from the desktop, where someone reads
  the plan first.
- **A run that stops early leaves the change behind.** A build failure or a cancel
  skips Terraform, and a failed or refused apply leaves it undone. Nothing retries
  it. The next merge that changes something on the list plans again and picks it up,
  and a merge off the list doesn't. Re-run the job if it's still the newest, or
  apply from the desktop.
- **An outage can turn an unrelated merge red.** A plan refreshes Cloudflare,
  Hetzner, UniFi and the Incus hosts, so one of them being down fails the step on a
  merge that changed nothing they care about. The hosts have already applied by
  then. Re-run the job once it's back.
- **The log is public.** caboodle is public, so its Actions logs are, and the plan
  and its refresh lines go there: hostnames, LAN addresses, MACs, DNS records,
  Cloudflare IDs, and a few things that read as personal when a resource changes
  or goes, like the email that created a Cloudflare token, a tunnel's connection
  details and the storage box's username and server. Terraform prints a
  `sensitive` attribute as `(sensitive value)`, and the tokens, tunnel secrets
  and passwords are all marked. A new variable or output holding a secret needs
  `sensitive = true`, or the next merge publishes it.
- **The lock.** Terraform Cloud holds the state and its lock, so the desktop and
  the runner can't corrupt each other. `-lock-timeout=10m` is how long a command
  waits to get the lock, so either one waits ten minutes for the other, then fails.
  It doesn't clear anything.
- **The runner's own guest.** Terraform manages the container the job runs in, so
  an apply that changes it can kill the job halfway and leave the lock held. Before
  the job applies, `scripts/terraform.sh` passes the saved plan through
  `scripts/terraform-guard.sh`, which stops the job on anything but a no-op on
  `incus_instance.guest["runner"]`, and on a delete or replace of any other
  guest, since that takes a container and its disk with it. It also stops on a
  plan it can't read or one that doesn't list the container, since a real plan
  always does. Nothing in that
  plan applies, other resources included, and the run goes red, as does every merge
  that plans after it until the desktop applies. The desktop leaves
  `TERRAFORM_SECRETS_DIR` unset, so it skips the guard. Run
  `scripts/terraform.sh apply` from a checkout of `main` while the runner is idle,
  then re-run the job, whose plan now finds nothing to do. Applying from the desktop
  before merging saves the red cross.
- **A lock left behind.** A job killed during an apply can leave the lock held, and
  no timeout clears that. Every plan after it waits its ten minutes and fails,
  printing the lock ID. On Terraform Cloud that ID is the same whoever holds the
  lock, so first check that nothing is really applying. Then, from the repo on the
  desktop in `nix develop .#full`, with the ID from the error. `force-unlock`
  wants an initialised backend, which the dev shell doesn't give a fresh
  checkout, so run `init` first with the same token. Terraform Cloud only lets a
  workspace admin force the lock off, so a token that can apply may still be
  refused here; if it is, the workspace's page in Terraform Cloud has the same
  button.

  ```sh
  export TF_TOKEN_app_terraform_io="$(cd modules/agenix && agenix -d terraform-cloud-token.age)"
  terraform -chdir=terraform init -input=false
  terraform -chdir=terraform force-unlock '<lock ID>'
  ```

- **What a plan costs.** Each one evaluates `.#network`, about 2 GB for a few
  seconds, and builds the Incus base image, which `linuxHosts` leaves out, for the
  external data source in `terraform/incus.tf`. That image takes only nixpkgs and
  its own modules from the flake, so a nixpkgs bump means a build even when no guest
  is new, and an `ai-skills` bump doesn't. All of it sits inside `runner.slice` with
  the job's other steps finished, so it needs nothing from the fence.

### What it holds

- **The inputs token.** `nix-inputs-token.service` writes
  `/run/nix-inputs-token/access-tokens.conf`, the file `nix.conf` includes, from
  the agenix copy, which stays root's. The job's group can read the new file,
  since Nix fetches flake inputs in the process that evaluates, not in the daemon.
  A workstation's daemon has no token either, and its deploys work. Nix silently
  skips an `!include` it can't read, so a file the group can't read shows up as a
  404 on the first private input. Root owns the file and its directory and the file
  is `0640`, because root's Nix and the daemon read it too, with no check on its
  owner: a job that could write it could set `plugin-files` and run code as root.
- **Its root SSH key.** `/run/agenix/runner-ssh-key` belongs to the job's user,
  and `/etc/ssh/ssh_config` names it. A job can read that key, since applying a
  guest needs it. Running colmena as root instead would need `sudo`, which the service's
  `NoNewPrivileges` forbids, and root on the runner could read the App's key,
  which [Registration](#registration) keeps away from jobs. Hive defaults set
  `homelab.deployedByRunner` from a host's tags, and `modules/guest.nix` only
  authorises the key where that's true, so PVE, Cube, the workstations and the
  Macs never see it.
- **The Terraform secrets.** The six `terraform-*` files in `/run/agenix` belong
  to the job's user, who only reads them. The job sets `TERRAFORM_SECRETS_DIR`, and
  `scripts/terraform.sh` reads the files instead of calling agenix, which would need
  Shane's key. A job can read them, like the SSH key, and the Cloudflare token can
  mint other tokens.

### Reaching the guests

A guest's `deployment.targetHost` is its hive name. MagicDNS answers that on
the desktop, but no server takes tailnet DNS, so on the runner it wouldn't
resolve. `networking.hosts` maps each deployed guest's name to its LAN address,
which also covers `dig @dns1`. Its `known_hosts` comes from
`modules/agenix/host-keys.nix` the same way. Accepting MagicDNS or adding
mappings to Blocky would make a deploy depend on Tailscale, or on the DNS guests
it's in the middle of switching.

The cost is that these are the names and keys from the runner's last deploy. A
new guest or a changed host key fails with a red cross until
`scripts/deploy.sh runner` from the desktop, then re-run the failed job.

Colmena, `dig`, `jq`, `ssh` and `terraform` are on the service's `PATH` rather than
coming from `nix develop .#full`, which would compile terraform and colmena on a
cold store and fetch the rest of the shell to reach five binaries. That means a
colmena or terraform bump reaches the job at the runner's next deploy. If a Sunday
bump makes the old command and the new flake disagree, it's a red cross with the
same fix.

### Nyx

Jovian documents no official binary cache, so every Valve kernel bump meant about
two hours of compiling here. [Chaotic Nyx](https://www.nyx.chaotic.cx/) is a
third-party cache that builds Jovian, so the runner's module lists it and trusts
its key. When Nyx holds the exact path the Deck asks for, the runner downloads it
and the log says `copying path '...' from 'https://nyx-cache.chaotic.cx'`.

It's on the runner alone because nothing else needs it. Every other host gets
these paths from the home cache under the home cache's key. That's why it isn't
in `upstream-caches.nix`, which the workstations share.

- **The key covers everything Nyx serves.** Nix can't trust a key for Jovian
  alone. Any store path the runner wants can come from Nyx if Nyx signed it. The
  URL's `priority=45` puts it behind every other cache, so it only answers when
  none of them has the path. Nyx advertises 30 itself, which would tie with the
  home cache and beat cache.nixos.org. The order limits what Nyx supplies, not
  what it could.
- **The signature is the trust, and it's Nyx's.** A store path's hash comes from
  the derivation's inputs, not from what the build produced, so a matching path
  says the recipe matched and nothing about the binary. The signature says Nyx
  stands behind it. Nobody here rebuilds it to check. When the two were compared
  on one kernel, `out` and `modules` were byte for byte the runner's own compile
  and `dev` wasn't, so even an honest match can differ. `dev` isn't in the Deck's
  closure. To compare again, read `narHash` from `nix path-info --json` on each
  store.
- **Downstream doesn't check.** `scripts/push-to-cache.sh` copies with
  `--no-check-sigs` and Harmonia signs what it serves, so a path from Nyx reaches
  every host whose closure holds it under the home cache's key, and the runner
  is the only place that checks Nyx's signature. The copy keeps Nyx's signature
  beside ours, so `nix path-info --sigs <path>` on the cache or on a host still
  names Nyx; that answers where a path came from after the fact, it doesn't gate
  anything.
- **A miss just builds.** A path Nyx doesn't have is a 404, and the runner compiles
  it as before. With Nyx down, `fallback` and `connect-timeout` in
  `modules/services/harmonia/client.nix` bench it [the same way as the
  cache](cache.md#when-its-down).
- **Matches aren't guaranteed.** Nyx pins its own nixpkgs and Jovian, and ours move
  on the Sunday bump. The kernel only matches while everything its derivation
  depends on matches, even though other parts of nixpkgs can differ. Nyx's docs
  say to follow Jovian through its flake to avoid exactly this, and caboodle
  doesn't, because that means taking Nyx as an input. So the job's timeout still
  allows for the compile.

To prove a download on the runner, whose store may already hold the path, use a
scratch store as root. Nix opens it in the client, so the daemon and the real
store aren't involved, and the keys are the ones `nix.conf` trusts:

```sh
s=$(mktemp -d)
nix copy --from https://nyx-cache.chaotic.cx --to "$s" <path>
nix path-info --store "$s" --sigs <path>
rm -rf "$s"
```

Without the key in `nix.conf`, or for a path it didn't sign, the copy fails with
`lacks a signature by a trusted key`.

### When the runner is down

`scripts/deploy.sh` from the desktop applies what the job applies, plus the mini,
and `scripts/terraform.sh apply` does the job's Terraform.
There's no lock between the two deploys, and
[ADR 0005](../adr/0005-merges-deploy-from-a-runner-at-home.md) says why. The
build and push steps run from the desktop too, from a clean checkout of `main`,
if the workstations want their closures before the runner is back:

```sh
scripts/push-to-cache.sh $(scripts/build-linux-hosts.sh)
```

## Fencing

Three layers keep a job off its neighbours. `homelab.guest.background` is the
outer one.

- **CPU.** `limits.cpu.allowance = 11%` with `limits.cpu.priority = 0` gives a
  `cpu.weight` of 1 against every other guest's 100. Priority alone only
  reaches 90, since Incus takes it as a tiebreak. 10% would come to 0, which
  the kernel refuses. The allowance is soft, so an idle PVE gives the runner
  all 8 cores.
- **Disk.** `limits.disk.priority = 0` gives an `io.weight` of 10. This does
  nothing yet, see below.
- **Memory.** `github-runner-homelab.service` and `nix-daemon.service` share
  `runner.slice`, whose `MemoryMax` sits a few GB under the guest's limit, and
  PVE has no swap to thrash. One slice rather than a cap on each service,
  because evaluation runs in the job's process and builds run in the daemon,
  and two separate caps would add up to more than the guest has. The cap is on
  the slice rather than in `scripts/quietly.sh`, so everything a job spawns is
  under it, wrapper or no wrapper. `OOMPolicy=continue` means the kernel kills
  the biggest process and the listener survives to report a red job. The
  daemon's `max-jobs` and `cores` are pinned low so a cold hive build can't
  run eight compilers at once into that cap. A cold run can compile the Valve
  kernel, Node, Mesa and Gamescope among others when no cache has that exact build,
  at idle priority, which is why the job's timeout is six hours.

`scripts/quietly.sh` still gives a job its lock and `nice`. Its
`systemd-run --user` scope can't work here, since the service has no user
manager, so it falls back as it does on a Mac. Getting one would mean lingering
and opening `/run/user` in the unit's sandbox, for a cap that a bare `nix eval`
in a job would walk around.

Inside the guest, the slice's `CPUWeight=idle` and `IOWeight=1` let SSH and
Tailscale win, and the daemon runs at idle CPU and I/O priority.

**The disk priority has no effect until PVE enforces `io.weight`.** Only the
iocost controller reads it. PVE's NVMes use the `none` scheduler and
`/sys/fs/cgroup/io.cost.qos` is empty, so a job's disk I/O competes evenly with
every guest on the pool. Writing `<major>:<minor> enable=1` for `nvme1n1` into
that file at boot turns iocost on, for every guest on that disk.

### Garbage collection

`nh clean` already runs weekly on every NixOS host through `modules/nixos.nix`,
and NixOS warns against `nix.gc.automatic` beside it. While a run is going, each
host's out-link, at `closures/<host>` under the job's temp directory, roots its
closure from the moment that host finishes, so neither the weekly clean nor a
`min-free` collection can take one between its build and its push. The job's last
step removes the links whatever happened before it, so after the run nothing roots
them, the clean takes them, and nothing notices: the next run fetches them back from
the cache.

The store holds one set of every Linux closure plus whatever a cold build had to
compile, and a lock-file bump lands most of that again beside it. `min-free` and
`max-free` in the module start a collection well before the disk alert fires and
stop it once there's room for another set. To see what a set costs today, `du -sh`
the links while a run is going, or `nix path-info -S` the cache's `per-host`
profiles; if a bump keeps collecting mid-run, raise the guest's disk. The disk is
thin, so it only takes what it uses from PVE's pool.

### Proving the fence

Run the smoke workflow with `runaway` ticked. The last step should fail with
exit 137, and the runner should stay online for the next job.
For the run's window, read these in Grafana:

- `rate(incus_cpu_seconds_total{instance=~"192.168.1.169.*"}[1m])`: the other
  guests' CPU should keep its usual shape.
- `incus_memory_OOM_kills_total`: only `runner` should move.
- `rate(node_pressure_memory_stalled_seconds_total{host="pve"}[1m])`: PVE
  itself should stay near zero.

## Nuking it

The state is disposable and the identity isn't. A new container has a new SSH
host key, which can't decrypt the guest's agenix secrets, so
`runner-ssh-host-key.age` holds the key, encrypted to Shane alone. The hive
deploys to the guest's LAN address, so a rebuilt guest doesn't need Tailscale
first.

On PVE, `incus delete --force runner`. Then from the repo on the desktop:

```sh
scripts/terraform.sh apply
(cd modules/agenix && agenix -d runner-ssh-host-key.age) \
  | ssh root@pve 'incus exec runner -- sh -c "umask 077 \
      && cat > /etc/ssh/ssh_host_ed25519_key \
      && ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub \
      && systemctl restart sshd"'
scripts/deploy.sh runner
```

The key goes in through PVE and `incus exec`, not SSH, because the new guest
answers with a freshly generated key that the desktop's `known_hosts` would
refuse. Writing the file isn't enough on its own: sshd keeps serving the key
it loaded at boot until it restarts, and the `.pub` beside it has to match.
Terraform keeps the MAC and the UniFi reservation, and its plan should only
touch `runner`. The runner mints a token, and `replace` takes over the old
registration's name. In the Tailscale console, delete the old node and rename
`runner-1`.

## Gotchas

- **A registered runner keeps an old token on disk.** The module stores
  `.current-token` in its state directory, mode 600. A registration token
  lasts an hour, so it's dead long before it could matter, but the file only
  stays RAM-only until the module copies it.
- **Changing the registration fails once, then heals.** A new label, name or URL
  makes the module wipe the state and register with the old token, which GitHub
  refuses. `Restart=on-failure` starts it again 30 seconds later, the oneshot
  finds no credentials and mints a new one. A switch can report the unit as
  failed in between.
- **A failed mint doesn't retry.** If GitHub or the permission is missing, the
  oneshot fails and the runner stays down, on purpose, so a switch can't hang
  waiting on GitHub. `systemctl start github-runner-homelab` tries again.
- **GitHub drops a runner offline for 14 days,** and credentials on disk won't
  bring it back. Stop the service, `rm -rf /var/lib/github-runner/homelab`, and
  start it.
- **The work directory is on disk,** at `/var/lib/github-runner-work`. The
  module's default is `/run`, which would count checkouts and Nix's fetcher
  cache against the memory cap. The module empties it on every start, and it's
  also the job's `HOME`.
