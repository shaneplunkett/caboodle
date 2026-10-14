# Builder

NixOS LXC on PVE that runs the Forgejo runner for the forge. The container
is `module "builder"` in `terraform/pve-builder.tf`, and the service is
`modules/services/forgejo-runner`. It keeps no state worth backing up, so a
dead builder is rebuilt from code.

## How jobs run

A job with `runs-on: nix` runs straight on the host, not in a container, so
the Nix store stays warm between runs and a second build is mostly cached.
The host has Nix, git, colmena, and node for JavaScript actions like
`actions/checkout`. Anything else a job needs goes in `hostPackages`, or
comes from `nix shell` inside the job. Old store paths are collected weekly.

The runner takes several jobs at once, so a few pull requests can build while
a deploy runs. They share one Nix store, and the Nix daemon makes sure two
jobs never build the same path twice. The container gets most of PVE's cores
but the lowest CPU weight on the node, so it has the whole CPU when the node
is idle and gives way to every other container as soon as they need it.

The builder also substitutes from the caches nix-config's machines trust.
The runner isn't a trusted user, so a flake can't add caches for itself, and
without them a desktop build compiles Hyprland and noctalia from source.

The host runs nix-ld, so binaries a job downloads for a generic Linux, like
the `ruff` that `uv sync` installs, run without patching. Without it they fail
with `Could not start dynamically linked executable`.

## Deploying

The deploy workflow runs `colmena apply --on @deploy-on-merge` on each push
to `main`. Its concurrency group queues deploys instead of cancelling them,
which is what Forgejo does by default for pushes. The builder's SSH key is an
authorised root key on every host, and its SSH config maps each host's name
to its LAN address from the hive, because the hosts don't use Tailscale's
DNS. It trusts each host by the key in `modules/agenix/host-keys.nix`.

dns2 is tagged `deploy-after-dns1` instead, and deploys in a second job once
the first has finished. Deploying both together restarts Blocky on both at
once, which left the network without DNS for about ten seconds. Before it
touches dns2, the job checks that dns1 answers a home name and an outside
name. If dns1 doesn't answer within a minute, the job fails and dns2 keeps
its old config, so a bad DNS change only ever takes down one of them.

The builder deploys on merge like the other hosts, even though the deploy job
runs on it. A switch that changes the runner reloads it instead of restarting
it, and the reload only schedules a restart for a few seconds later. It can't
queue the restart straight away: systemd would fold the restart into the
reload's job, the switch would wait on the restart, and the restart would wait
on the deploy that's running the switch. The restart is graceful: the runner
stops taking jobs, waits up to an hour for the ones it's running, including
the deploy itself, then comes back on the new config. `KillMode=mixed` is what
lets those jobs finish: systemd signals only the runner, and only kills its
jobs once the runner has exited. A restart that cuts a
job off shows as `RUN signal: terminated`, which means a job ran longer than
the hour.

## Job temp files

Jobs run on the builder itself, not in throwaway containers, so whatever a
job leaves behind stays for the next one. The runner's private `/tmp` is a
small tmpfs that only clears when the runner restarts, and a few test
databases once used up all its inodes, failing every job. So `TMPDIR`
points jobs at `/var/lib/forgejo-runner/builder/tmp` on disk, and
systemd-tmpfiles deletes anything there older than a day. A workflow that
writes to `/tmp` directly bypasses this, so use `mktemp` or `$TMPDIR`.

## Updates

The update workflow runs weekly, or from the Actions tab with Run workflow.
It calls `flake-update.yml` in `shane/workflows`, shared with nix-config, and
the README there covers what it does and its inputs. Inputs pinned to a
commit in `flake.nix` don't move with `nix flake update`, so it only moves
the unpinned ones, and Renovate moves the rest (see
[Flake inputs](#flake-inputs)). In short, it pushes the
`nix flake update` to `update/flake-lock` as `forge-bot` and opens a pull
request straight away, so `build.yml` checks the real head while the update
builds every host in `hydraJobs` before and after. Then it fills the
description in with each host's package changes and each moved input, and
asks `metrokitten` to review, which pings Discord. A pending `flake-update`
check on the pull request means it's still going. If last week's pull
request is still open, it updates that one instead. Merging it deploys like
any other change.

`hydraJobs` is the hive's `toplevel`, every host's system. `forge-bot` gets
Write through the `bots` team. Its token is `forge-bot-token`, in Bitwarden
and agenix, and the runner loads it as a credential. A pull request can't ask
its own author for a review, which is why the updates come from a bot and
not from your account.

## Terraform

The terraform workflow runs when a pull request touches `terraform/`, and
posts the plan as a comment, which is where to check it. Run workflow from
the Actions tab only plans, which is a quick way to look for drift.

On `main`, the deploy workflow applies first, then deploys the hosts. A
change to a container, like its memory, can restart it, and a restart in
the middle of colmena's push drops the SSH connection and fails that host's
deploy. So the apply finishes first, and skips itself when the push didn't
touch `terraform/` or `proxmox/`. If the apply fails, no host deploys.
`scripts/terraform-ci.sh` runs both the plan and the apply, and each waits up
to ten minutes for the state lock, since a pull request's plan can overlap
an apply.

State stays in Terraform Cloud. The builder reaches it with
`terraform-cloud-token`, a user API token in Bitwarden as `homelab_tfc_token`,
and the Proxmox and Hetzner tokens come from `homelab_pve_token` and
`homelab_hcloud_token`. All three are agenix secrets the runner loads as
credentials. The step that sets a container's devices and bind mounts runs
`pct` over SSH as `shane`, so the builder's key is in `shane`'s authorized
keys on both nodes.

## Renovate

Renovate runs on the builder every morning at 06:30 Melbourne time, as
`forge-bot`, for the pins a flake update doesn't touch: container images in
Nix modules, flake inputs pinned to a tag or a commit, the `npx` packages in
the dev shell, and Terraform providers. The service's config makes "before
9am on Sunday", Melbourne time, the default schedule for every repo, so new
pull requests still turn up as a Sunday batch and the other mornings only
keep open ones current. Each update is its own pull request asking `metrokitten` to review,
which pings Discord. The repo's rules are in `renovate.json`.

### Flake inputs

Renovate's Nix manager only updates an input whose commit is written into
`flake.nix`. For an input that's only locked in `flake.lock` it offers
nothing per input, just lock file maintenance, which is one pull request for
everything. So the inputs it owns are pinned, `github:owner/repo/<commit>`,
or `git+https://github.com/owner/repo?ref=<branch>&rev=<commit>` for one that
follows a branch, since `github:` won't take a branch and a commit together.
To add one, write its current commit into the URL and run `nix flake lock`.

Each pinned input gets its own pull request, on any morning rather than
only Sunday. The Noctalia shell and greeter share one, and so do nix-darwin
and home-manager. When Renovate opens one it asks Forgejo to merge it once
the checks pass (`platformAutomerge`), and nothing asks for a review. So a
busy input like llm-agents or noctalia's `cachix` branch merges the moment
CI goes green, rather than waiting for a run of Renovate that didn't just
push a newer commit, which on a daily schedule could take weeks.

That relies on `main` requiring the build check, set in
`terraform/forge-config.tf`. Without required checks, Forgejo merges a
scheduled pull request on the first status it sees, pending or failed. The
required contexts are globs over the status names, and Forgejo takes the
worst state across everything a glob matches:

- `/ hosts`, the job that lists the hosts. The per-host builds only exist
  once it finishes, so without it a pull request could pass on `check`
  alone before any build had started.
- `/ build (*)`, every host's build.
- `/ check*`, the check. The caller's job and the called workflow's job are
  both named `check`, so Forgejo calls one of them `check-1`.

Each name starts with `/ ` because the called workflows have no `name:`. If
one gains a name, or a job is renamed, nothing matches and every pull
request waits as pending, so the contexts need changing with it. Shane, as
an org owner, can still merge past a failed check.

`minimumReleaseAge` is off for these, because Renovate reads commits through
`git-refs`, which has no release dates, so the one-day wait would hold every
input forever.

The rest stay unpinned, and the weekly update below moves them in one pull
request for review:

- nixpkgs, because it moves every host at once. Renovate couldn't track it
  anyway: it matches lock node names against input names, and the root's
  nixpkgs isn't the node called `nixpkgs` while another input locks its own.
- electron-nixpkgs, which a pin would turn into a clone of nixpkgs.
- The Homebrew taps, which change every few minutes, so their pull request
  would never sit still for a run.
- The inputs on the forge. Renovate has no SSH key, so it can't reach
  `forgejo@forge`, and `renovate.json` turns them off.

### Repos and lock files

It finds repos by itself, by listing every repo in the `shane` org
(`autodiscoverNamespaces`). Each one gets an onboarding pull request first,
unless it already has a `renovate.json`, and closing that pull request
without merging tells Renovate to leave the repo alone. Renovate's default
search only returns repos the bot has access to and the public couldn't see
anyway, so once the org went public it stopped finding the public ones.
Renovate regenerates lock files with whatever is in `runtimePackages`:
`nodejs` (npm), `pnpm`, `uv`, `go`, and Nix for `flake.lock`. A repo whose package manager isn't
there gets pull requests that change the manifest but not the lock file,
with an "Artifact update problem" comment and an empty error, so add the
tool to the list.

`renovate-github-token` is a read-only GitHub token, because GitHub refuses
to list tags and releases without one. To run it now:

```sh
ssh root@builder systemctl start renovate
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

## Binary cache

Harmonia serves the builder's own Nix store at `cache.shaneplunkett.com`, so
anything a job builds can be downloaded by other machines instead of built
again. Nothing is pushed to it: building something is what puts it in the
cache. Paths are signed on the way out with `nix-cache-signing-key`, which is
in Bitwarden and agenix. A machine trusts the cache by its public half:

```sh
rbw get nix-cache-signing-key | nix key convert-secret-to-public
```

The store is collected weekly, so a build only stays in the cache while
something roots it. A job that wants its result kept builds with
`--out-link` into the runner's state directory, and replaces the link each
run so only the latest build is held. Full desktop and Mac closures are tens
of gigabytes each, so Nix also collects garbage by itself whenever free space
drops below `min-free`, and roots keep the latest builds safe from it.
`min-free` has to leave more room than the disk alert does, or Discord
hears about a full disk before Nix gets a chance to clear it.

The name only resolves through Blocky, so the cache is reachable on the LAN
and the tailnet and nowhere else.

## Darwin builds

The builder can't build for macOS, so it hands `aarch64-darwin` builds to
mini-server over SSH, and the results come back into its store and the
cache. That's how nix-config's Macs get built here. The Nix daemon makes the
connection as root with `builder-ssh-key`, logging in as `shane`. On
mini-server, nix-config pins that key to `nix-daemon --stdio`, so it can
build but can't open a shell.

mini-server's address is fixed in `darwin-builder.nix`, so it needs a DHCP
reservation like the LXCs. If darwin builds start failing to connect, check
that first.

## Fetching other repos

The forge needs a sign-in to see anything, and a job's own token only reaches
the repo it's running for. So flake inputs from other forge repos, like
`vex-brain`, come over SSH with the builder's own key, `builder-ssh-key`.
The runner loads it as a credential, and the host's SSH config uses it for
`forge`. It's added to each repo the builder fetches as a read-only deploy
key. To print the public half for a new repo:

```sh
ssh root@builder ssh-keygen -y -f /run/agenix/builder-ssh-key
```

## Gotchas

- **Changing a container's memory in Terraform reboots it.** The provider
  restarts the container after a memory change, though Proxmox could apply
  it live. For the builder that means rebooting in the middle of its own
  apply. Resize it by hand first with `pct set <vmid> --memory <MiB>` on the
  node, so the plan has no memory change left to apply.
- **`rbw add` and `rbw edit` read from stdin** when it isn't a terminal, and
  only the first line becomes the password. A multi-line value like an SSH
  key can't live in Bitwarden that way, so `builder-ssh-key` exists only in
  agenix. If it's lost, make a new one and replace the deploy keys.
- **Registering without `--keep-labels` wipes the runner's labels.**
  `forgejo-runner-register` re-runs whenever Forgejo restarts, and the
  runner only declares its labels when it starts itself. Without the flag,
  every forge restart left the runner online with no labels, and jobs waited
  for a runner with `nix` that never came.
