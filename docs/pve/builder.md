# Builder

NixOS Incus container on PVE. Until the GitHub cutover it runs the forge's
Forgejo runner, for the check, the weekly flake update and the `ai-skills`
bump, and the self-hosted Renovate. Nothing else builds or deploys here any
more; [ADR 0004](../adr/0004-the-desktop-builds-and-deploys.md) says why.
The runner is `modules/services/forgejo-runner`, and the guest keeps no
state worth backing up, so a dead builder is rebuilt from code.

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
- The runner isn't a trusted Nix user, so a flake can't add caches for
  itself. The builder trusts the workstations' caches instead, or a desktop
  build would compile noctalia from source.
- The private flake inputs come from GitHub with `github-inputs-token`, which
  a step before the runner starts writes as Nix's `access-tokens` into
  `/run/forgejo-runner-builder/nix.conf`, in RAM and readable only by the
  runner. A new private input has to be added to the token's repositories on
  GitHub, or its fetch fails with a 404.

## Memory

The flake update evaluates and builds every host, one after another, before
and after the bump, and builds happen in nix-daemon outside the runner. The
runner is capped at 32 GB.

- Past the cap the kernel kills the biggest process in the runner, almost
  always an evaluation. `OOMPolicy=continue` stops systemd taking the whole
  runner down over it, so that job fails and the others carry on. Re-run it.
- If the runner thrashes below the cap instead, systemd-oomd kills it whole
  once its memory pressure stays over 50% for 20 seconds, every running job
  fails, and systemd restarts it. That second line is unproven as set up
  here: hitting the cap alone leaves the pressure near 0, so the kernel kill
  comes first. oomd used to watch `system.slice`, which never fired, because
  "full" pressure means every task in the cgroup stalled at once and other
  services kept the slice going; the box went unreachable twice in one day
  until an `incus restart builder`.
- To test the backstop, run one evaluation as a transient unit under a small
  cap and watch it from a second SSH session, never through the runner. Copy
  a checkout into a `mktemp -d` on the builder first, and only start with
  more than 30 GB free:

  ```sh
  systemd-run --unit wedge-test -p MemoryMax=6G \
    -p ManagedOOMMemoryPressure=kill -p ManagedOOMMemoryPressureLimit=50% \
    -p ManagedOOMMemoryPressureDurationSec=20s -p CPUQuota=400% \
    -p RuntimeMaxSec=900 --wait --collect \
    nix eval --no-eval-cache --json "path:$dir#hydraJobs" \
    --apply 'jobs: builtins.mapAttrs (_: job: job.drvPath) jobs'
  ```

  The kernel kills it as it reaches 6 GB. To see oomd fire instead, add
  `-p MemoryHigh=4G` and raise `MemoryMax` to 8G: the kernel throttles
  rather than kills, the pressure climbs past 50%, and
  `journalctl -u systemd-oomd` logs the kill. Without `--no-eval-cache`, a
  revision the builder already evaluated proves nothing.

## Switching it

The desktop deploys the builder like any other guest. A switch reloads the
runner rather than restarting it, and the reload schedules a graceful
restart a few seconds later, so running jobs finish first. A job that ends
in `RUN signal: terminated` outlasted the stop timeout.

Don't switch it twice while the runner is draining. Every switch restarts
`sysinit-reactivation.target`, and while the runner is stopping that
restart waits for the stop, which waits for its jobs. New units queue
behind it, SSH stops answering, and only `incus restart builder` on PVE
clears it.

## Updates

Renovate opens two pull requests early on Sunday, nobody is asked to review
them, and both merge themselves once the check passes. One holds every
dependency update. The other is lock file maintenance, which runs
`nix flake update` and so moves every input that isn't pinned in
`flake.nix`; Renovate never groups it with anything else. The check builds
nothing, so a bump that breaks a host lands anyway and shows up at the next
`scripts/deploy.sh`. Revert it then. The `flake-update` skill still triages
a lock file change when asked.

`ai-skills` doesn't wait for Sunday. Each push to its `main` dispatches
`ai-skills.yml` here with forge-bot's token, which runs the same workflow
with `only: ai-skills` on its own branch and merges once the check passes.
The review happened in `ai-skills`, so a bad skill is fixed by reverting it
there, and the next push carries the revert over.

## Renovate

Renovate runs on the builder every morning as `forge-bot`, on caboodle
only. It moves container images in Nix modules, flake inputs, the dev
shell's `npx` packages, Terraform providers and workflow pins. Only the
Sunday run opens pull requests; the other mornings refresh one that's still
open. The repo's rules are in `renovate.json`. To run it now:

```sh
ssh root@builder systemctl start renovate
```

The same rules also run on GitHub as the App ([On GitHub](#on-github)). The
builder's timer stays only until cutover, when GitHub's pull requests become
the real ones.

### Flake inputs

Lock file maintenance moves every input that's only in `flake.lock`. An
input whose commit is written into `flake.nix` is pinned, and Renovate bumps
it in the dependency pull request instead. To pin one, write it as one of
these, then run `nix flake lock`:

- `github:owner/repo/<commit>`
- `git+https://github.com/owner/repo?ref=<branch>&rev=<commit>` to follow a
  branch, since `github:` won't take a branch and a commit together.

Renovate's pull requests merge themselves: Renovate asks Forgejo to merge
once the checks pass. That only works because `main` requires the build check
(`terraform/forge-config.tf`). Without required checks, Forgejo merges on
the first status it sees, pending or failed. The required contexts are globs
over job names, so renaming a CI job, or giving a called workflow a `name:`,
leaves every pull request pending until the contexts follow. `/ hosts` is
required because the per-host builds don't exist until it finishes, and
`/ check*` has its wildcard because Forgejo calls one of the two jobs named
`check` `check-1`. Shane can still merge past a failed check.

On GitHub, Renovate merges them itself rather than asking GitHub to, since
nothing there requires a check yet and GitHub won't auto-merge without one.
It merges on its next run once every check on the branch has passed, so a
pinned input lands the morning after its pull request goes green.

`minimumReleaseAge` is off for pinned inputs, because `git-refs` has no release
dates and the wait would hold every input forever.

Only the fast movers are pinned: `llm-agents` and the Homebrew taps.
Everything else moves with the lock file, and these can't be pinned anyway:

- nixpkgs, because another input locks its own `nixpkgs` node.
- electron-nixpkgs, which a pin would turn into a clone of nixpkgs.

Moving an input between the two without moving its lock means editing its
`original` in `flake.lock` to match the new URL, adding or dropping the
`rev`. Change only `flake.nix` and `nix flake lock` relocks it at the
latest commit.

### Repos and lock files

- Renovate runs on `shane/caboodle` alone, named in `repositories`. The
  forge's other repos get no Renovate.
- It regenerates lock files with the tools in `runtimePackages`. A repo
  whose package manager isn't there gets an "Artifact update problem"
  comment with an empty error, so add the tool.
- Its github.com token is the inputs token
  ([below](#github-app-and-inputs-token)). GitHub won't list tags and
  releases without a token, and Renovate hands the same one to
  `nix flake update`, which needs it for the private inputs.

### On GitHub

`.github/workflows/renovate.yml` runs Renovate as the App from a hosted
runner, every day at 19:30 UTC: 06:30 in Melbourne's summer, 05:30 in
winter, so inside the Sunday batch either way. Run workflow on its Actions
page runs it now. Its global config is the `RENOVATE_CONFIG` in the
workflow, the builder's `settings` with these differences:

- It only runs on caboodle (`autodiscoverFilter`), and onboards nothing.
- A config has to extend `github>shaneplunkett/workflows`, which resolves on
  both forges. `local>shane/workflows` looks for `shane` on GitHub, which is
  someone else, so Renovate rejects the repo's config.
- `force` makes `shaneplunkett` the reviewer, since `metrokitten` on GitHub
  is also someone else, and turns off `platformAutomerge`. It comes off at
  cutover.
- Commits go through GitHub's API (`platformCommit`), so GitHub signs them
  and authors them as `caboodle-agent[bot]`. The App's token also covers
  github.com's tags and releases, so the inputs token isn't needed.
- Renovate's container installs `nix`, `uv`, `pnpm`, Go and Node when a
  lock file needs them, the same tools `runtimePackages` gives the builder.
- Renovate reads a branch's Actions results as check runs, which needs the
  App's Checks permission on private repos. Without it a private branch
  looks pending forever and never automerges.

Until cutover the forge's push mirror runs `git push --mirror`, which
deletes any GitHub branch the forge doesn't have. So every pull request
Renovate opens on GitHub closes at the forge's next push, and these are
only a preview. Its branches start with `renovate-github/` so the forge's
own `renovate/` branches can't overwrite them, which would leave Renovate
treating the pull request as edited by someone else. `branchPrefixOld` is
set to the same prefix, because its default is `renovate/`: left alone,
Renovate adopted the forge's mirrored branch as its own old-prefix branch,
saw `forge-bot`'s commit on it as someone else's edit, and skipped the
update without a word at its normal log level. The prefix also keeps
the closed ones away from cutover: Renovate skips any update whose pull
request was closed unmerged, and it matches them by branch name, so
dropping the prefix at cutover starts GitHub clean.

## GitHub App and inputs token

Both are in Bitwarden and in caboodle's Actions secrets on GitHub.

- **The App** is `github-app-client-id` and `github-app-private-key`
  (`APP_CLIENT_ID` and `APP_PRIVATE_KEY` in Actions). It's installed on every
  repo on Shane's account, with read and write on contents, pull requests,
  issues, actions, workflows and commit statuses, and read on checks and
  Dependabot alerts. Jobs and Renovate mint an
  hour-long installation token from it. Bitwarden holds the key base64'd,
  since `rbw` keeps one line: `rbw get github-app-private-key | base64 -d`.
- **The inputs token** is `github-inputs-token` (`INPUTS_TOKEN` in Actions),
  a fine-grained token with contents read on vex-brain, nix-config-private,
  ai-skills, noctalia-plugins and wallpapers, for fetching those inputs. It
  is also Renovate's github.com token on the builder. It never expires,
  since it can only read.

To replace the token, regenerate it on GitHub's fine-grained tokens page,
then from `modules/agenix`:

```sh
rbw edit github-inputs-token
printf '%s' "$(rbw get github-inputs-token)" | agenix -e github-inputs-token.age
printf '%s' "$(rbw get github-inputs-token)" | gh secret set INPUTS_TOKEN --repo shaneplunkett/caboodle
```

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

## Store and cache

`attic-watch-store` pushes every path that lands in the builder's store to
the [cache](cache.md), as it lands. The store only keeps a build while
something roots it, since it's collected weekly and whenever free space
drops below `min-free`. The disk alert is set 5 GiB past `min-free` in
`hosts/builder.nix`, so Discord only hears about a full disk when
collection can't keep up.

The builder hands `aarch64-darwin` builds to the mini over SSH, as `shane`
with `builder-ssh-key`. The mini's address is fixed in `darwin-builder.nix`,
so if darwin builds stop connecting, check its DHCP reservation first.

## Gotchas

- **`rbw add` and `rbw edit` read from stdin** when it isn't a terminal, and
  only the first line becomes the password. A multi-line value like an SSH
  key can't live in Bitwarden that way, so `builder-ssh-key` exists only in
  agenix. If it's lost, make a new one and swap its public half in wherever
  the hosts authorize it: `modules/guest.nix`, `modules/darwin`, and PVE's
  and Cube's host files.
- **Registering without `--keep-labels` wipes the runner's labels.**
  `forgejo-runner-register` re-runs whenever Forgejo restarts, and the
  runner only declares its labels when it starts itself. Without the flag,
  every forge restart left the runner online with no labels, and jobs waited
  for a runner with `nix` that never came.
