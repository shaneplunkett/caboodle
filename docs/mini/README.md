# The Mac mini

The mini is a Mac server in the hive, deployed with `scripts/deploy.sh mini`
like the other servers. Colmena runs from a fork that can deploy darwin
nodes until upstream merges it, and the mini builds on itself
(`deployment.buildOnTarget`), since the desktop can't build darwin. It's a workstation too, so
[docs/workstation](../workstation/README.md) covers what it shares with the
desktop and the MacBook.

vex-brain's vex-sync runs as daemons rather than home-manager agents, so
sync runs from boot with nobody logged in.

It also builds itself and the MacBook on every merge and pushes both to the
[cache](../pve/cache.md); see [the runner](#the-runner).

## BlueBubbles

BlueBubbles Server is how Shane uses iMessage from NixOS. Homebrew disabled
its cask because it fails Gatekeeper, so `pkgs/bluebubbles-server` packages
the upstream DMG instead, and `home/shane/modules/mini-server/bluebubbles.nix`
runs it as a login agent. `pkgs/bluebubbles-themed` is the Linux client, a
different thing.

The app is signed with the developer's Developer ID but not notarized, which
is what Gatekeeper rejects. Gatekeeper only assesses quarantined downloads,
and nothing in the Nix store is quarantined, so it never runs. Full Disk
Access and Accessibility are granted to the bundle ID and signing team, not
the path, so the grants survive the move into the store and every rebuild,
as long as the bytes stay as signed. That's why the package skips fixup:
stripping or patching anything would break the signature and lose the
grants.

The agent copies upstream's own LaunchAgent: restart on a crash or a
non-zero exit, not on a clean one. The app takes a single-instance lock and
exits cleanly when another copy is running, so a second launch stays down
rather than looping.

Clients reach it at `https://bubbles.shaneplunkett.com`, through ingress
like any hive route. There's no oauth2-proxy gate in front: it's an API that
the client apps call with the server password, and they can't do a browser
sign-in.

Its settings live in its own database under `~/Library/Application
Support/bluebubbles-server`, so these can't be declared and have to be set
in the app:

- **Auto Start Method** must be "Do Not Auto Start". Its login item or its
  own LaunchAgent would race the declared one. Switching away from "Launch
  Agent" boots out the job the app is running under, so it quits on the
  spot; start the declared agent afterwards.
- **Server Address** is `https://bubbles.shaneplunkett.com`, the address
  its pairing QR code gives clients.
- **Check for Updates** should be off. The store is read-only, so its
  updater can't install anything. Updates come from bumping the package.

### Moving from the hand-installed app

The first deploy is harmless: the hand-installed copy is already running, so
the declared one exits on the lock. Then, on the mini:

1. In BlueBubbles' settings, set Auto Start Method to "Do Not Auto Start" and
   turn off Check for Updates.
2. Quit BlueBubbles and delete the hand-installed `BlueBubbles.app`.
3. `launchctl kickstart gui/$(id -u)/org.nix-community.home.bluebubbles`
4. Check a message gets through on the desktop, with no permission prompts
   on the mini.

Its log is `~/Library/Logs/bluebubbles-server.log`.

## The firewall

The macOS application firewall lets signed apps accept connections and
silently drops the rest, and anything Nix builds is only ad-hoc signed. So
it's off, which makes the mini a LAN server like the rest, whose firewalls
open each service's port to the whole LAN anyway. That's what lets
Prometheus scrape it.

macOS's node exporter has no `MemAvailable`, so the host dashboard works it
out the way Activity Monitor does: total memory less app memory, wired and
compressed. `modules/services/prometheus/memory.nix` holds both versions.
Free memory alone means nothing on a Mac, because macOS fills spare memory
with file cache on purpose. The disk alert works as on the other servers.

## Screen Sharing

The mini usually has no screen or keyboard of its own, so Screen Sharing is on.
From the MacBook, open `vnc://mini-server` in Finder's Connect to Server and log
in as `shane`, the only account on its access list. nix-darwin has no option for
it, so the activation script in `hosts/mini.nix` starts the service and adds
`shane` to the list. Like every other port on the mini, 5900 is open to the LAN
as well as the tailnet.

## Tuned for agents

The mini is the only T3 Code backend, so it's tuned for agents spawning lots
of short processes over lots of small files, not for someone sitting at it.

- **The server runs `Interactive`.** A launchd job with no `ProcessType`
  gets light CPU and I/O throttling, and everything it spawns inherits it, so
  every agent's shells, git and test runs were clamped. `Interactive` lifts
  that. The nix-daemon stays `Standard` on purpose, so agents win over darwin
  builds from CI.
- **Spotlight is off on every volume.** Nothing here searches, and every
  install, checkout and worktree cleanup made `mds` index the churn.
  Spotlight's privacy list can't be declared, so it's all off rather than
  some folders excluded. Activation turns it back off on each deploy, since
  a macOS update can turn it on again.
- **git keeps an untracked cache.** `git status` skips rescanning directories
  that haven't changed, which matters when agents call it constantly.

### The first-run scan

macOS scans every new executable the first time it runs, about a quarter of
a second each. Every Nix rebuild, native npm package or freshly compiled test
binary pays it once. Apps in Privacy & Security › Developer Tools, and
everything they spawn, skip the scan. That grant lives in TCC, which only the
UI or an MDM profile can change, and it's keyed to a path or a signature that
moves into a new store path with each vex-code bump. So it isn't declared
here.

## The runner

This is a trial. The [runner on PVE](../pve/runner.md) can't build darwin, so a
second one lives here and only builds. On a push to `main` that touches anything
outside `docs/`, `.github/workflows/darwin.yml` runs
`scripts/push-to-cache.sh mini macbook macbook-air`, which builds each Mac through
`scripts/quietly.sh`, copies the closure to the cache and sets its profile. A
build that fails turns the run red, and a red run pushes nothing after the host
that broke. It never switches anything. The module is
`modules/services/github-runner/darwin.nix`, and
[ADR 0005](../adr/0005-merges-deploy-from-a-runner-at-home.md) has the why.

The trial's risk is that nothing fences it. `quietly.sh` on a Mac is a lock and
`nice`, there's no Incus layer, and nothing caps memory. The job runs as
`ProcessType = Background`, where nix-darwin's module would give it
`Interactive`, so an evaluation loses to the agents. Builds run in the
nix-daemon, which stays `Standard`.

### Turning it off

```sh
gh workflow disable darwin.yml --repo shaneplunkett/caboodle
```

That needs no deploy, and the next merge builds nothing here. To stop a build
that's running now, `sudo launchctl bootout system/org.nixos.github-runner-mini`.
A deploy only reloads a plist that changed, so an ordinary one leaves the runner
booted out. It comes back with a reboot, a deploy that changes the plist, or by
hand:

```sh
sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.github-runner-mini.plist
```

If the trial ends, delete the workflow and the module's line in `hosts/mini.nix`,
then deploy. Do it in that order: a job with no runner to take it sits queued for
GitHub's 24 hours, then fails. The MacBook goes back to building what the cache
lacks. `_github-runner`, its state in `/var/lib/github-runners` and its entry on
GitHub's runners page stay behind until someone removes them.

### What to watch

BlueBubbles is the one that hurts, so a message arriving late during a run is the
signal to turn this off. Its log is `~/Library/Logs/bluebubbles-server.log`. T3
Code and vex-sync share the machine too, and the host dashboard has the memory
and CPU. The first run and the weekly lock bump are the real test, since they
compile the most, and the first run also has everything only the MacBook carries
to fetch or build.

### What it holds

It runs as `_github-runner`, the user nix-darwin's module creates. That user isn't
an admin or a Nix trusted user, and it can't enter `/Users/shane`, so Shane's SSH
keys, her `access-tokens.conf` and her keychain are out of reach. It gets two
things from agenix:

- **The inputs token.** The `nix-inputs-token` daemon writes
  `/run/nix-inputs-token/access-tokens.conf` from the agenix copy, which stays
  root's. `nix.conf` includes that file. Nix reads it in the process that
  evaluates, so the job's group can read it. Root owns it and it's `0640`, because
  root's Nix and the daemon read it too, with no check on its owner: a job that
  could write it could set `plugin-files` and run code as root. The directory has
  to stay `0755`. Nix skips an include it can't read, which is what Shane's own Nix
  does, but a closed directory fails the `stat` first, and then every Nix command
  for everyone else on the mini loses its whole `nix.conf`.
- **A key to the cache.** `/run/agenix/mini-cache-ssh-key` belongs to the job's
  user, and `/etc/ssh/ssh_config.d` names it for `cache.home.arpa`. Only
  `hosts/cache.nix` accepts its public half.

`flock` and `ssh` are on the job's `PATH` through `extraPackages`, since macOS has
no `flock` and the job's `PATH` has nothing from `/usr/bin`. A new tool reaches the
job at the mini's next deploy.

### Registration

launchd has no ordering between jobs, so nothing runs "before" the runner. The
`github-runner-registration` daemon runs as root at load and every five minutes
instead. Agenix links the App's two secrets into `/run/github-app`, and the daemon
points `github-app-token` at that folder, as `LoadCredential` does on PVE. It mints
with the same `registration-token.sh`, but it has no copy-back like PVE's. Nothing
stops a job writing anything into the state directory here, so the daemon only ever
tests for `.runner` and never reads out of there.

- With no `.runner` in `/var/lib/github-runners/mini`, it mints a registration
  token into `/run/github-runner-registration/token`. The runner's user owns that
  file, because the module's script reads it as that user.
- With `.runner` there, it removes the file and calls nothing. `/run` is on disk on
  a Mac, so a dead token sits there for up to five minutes after registering.

The runner's job is set to `KeepAlive`. Before it has a token it fails and starts
again 30 seconds later, and launchd also starts it when the token file appears. The
module only registers when `.runner` is missing, so unlike PVE, changing a label or
the name does nothing by itself. To register again, or after GitHub drops it for 14
days offline:

```sh
sudo rm -f /var/lib/github-runners/mini/.runner /var/lib/github-runners/mini/.credentials*
sudo launchctl kickstart -k system/org.nixos.github-runner-registration
sudo launchctl kickstart -k system/org.nixos.github-runner-mini
```

The logs are in `/var/log/github-runners`.

### The guard

This runner holds the cache key and the inputs token, so it takes the same
job-started hook as the one on PVE and refuses every job that isn't from caboodle's
`main`. [The guard on PVE](../pve/runner.md#the-guard) has how it works, its limits and
how to prove it, and all of that applies here. Two things differ:

- launchd sets `ACTIONS_RUNNER_HOOK_JOB_STARTED` from the plist, where PVE has systemd.
- The runner's user removes `.env` from the state directory at the top of the job's
  script, since launchd has no step before it.

A Mac has no `ps` on the job's `PATH`, so the hook adds `/bin` to find the worker.

## Deploying

A merge builds the mini but doesn't switch it. Its tag is `deploy-mini`, so the
[deploy job](../pve/runner.md#the-deploy-job) skips it, and `scripts/deploy.sh` with
no arguments applies it from the desktop along with the guests. With a green
`darwin` run on that commit, the closure is already in the store and the switch
takes seconds. Later the ADR has the switch become a by-hand pull from the cache,
but today it's still this.

`scripts/deploy.sh mini` deploys it from the desktop: colmena reaches it as
`shane` with Shane's key, builds on the mini, and runs `sudo` without a
password. Tailscale is the Homebrew app, so colmena uses its LAN address.

The first switch has to happen on the mini, because the passwordless sudo
rule is part of the system being switched to. Use the recipe in
[docs/workstation](../workstation/README.md#switching-a-mac) with
`-H mini`. The hostname stays `mini-server` so the tailnet name, and
Tailscale Serve for vex-code, don't change.

## Gotchas

- `deployment` attributes in `hosts/mini.nix` must be plain values. Colmena
  reads `deployment.systemType` before it evaluates the host, with the NixOS
  module path, and a value that depends on the rest of the config fails there.
- Root's `PATH` on macOS has no Nix, so colmena runs Nix from
  `/run/current-system/sw/bin`. That needs nix-darwin to manage Nix, which
  it does by default and which the Lix installer doesn't get in the way of.
