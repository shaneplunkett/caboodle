# The Mac mini

The mini is a node in the hive like the LXCs, evaluated with nix-darwin and
deployed by colmena, which runs from a fork that can deploy darwin nodes
until upstream merges it. The PR build check builds its system on the mini
itself, since it's also the builder's darwin remote builder.

## What the hive gives it

`darwinDefaults` in `flake.nix` is the Mac counterpart of `nixosDefaults`:
Nix settings and the homelab cache, weekly GC, fish, Shane as the primary
user with the builder's key, and node exporter when `homelab.monitoring` is
on. The host file adds the deploy settings, auto-login, and staying awake.

It's also a machine Shane sits at, so it imports `modules/workstation` and
`modules/workstation/darwin`, the same modules the MacBook gets. They
bring home-manager, which the host file points at
`home/shane/homemacserver.nix`, and Homebrew through nix-homebrew. That
home config runs vex-code as a login agent. The host file also adds
vex-brain's vex-sync daemons and turns off the home-manager sync agents they
replace, so sync runs from boot with nobody logged in.

The mini's nixpkgs is `workstationPkgs` in `flake.nix`, which adds the
overlays from `pkgs/overlays.nix`. The LXCs don't get them: one of them
patches `forgejo-cli`, which the forge host runs.

## Homebrew

nix-homebrew owns `/opt/homebrew`, with the core and cask taps pinned as
flake inputs, and `onActivation.cleanup = "uninstall"` removes any cask or
formula that isn't declared. The first activation from the hive removes the
ChatGPT and Claude casks nix-config installed, on purpose, since a headless
server doesn't want them. Anything that should stay has to be declared.

## BlueBubbles

BlueBubbles Server is how Shane uses iMessage from NixOS. Homebrew disabled
its cask because it fails Gatekeeper, so `pkgs/bluebubbles-server` packages
the upstream DMG instead, and `home/shane/modules/mini-server/bluebubbles.nix`
runs it as a login agent. `pkgs/bluebubbles` is the Linux client, a
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

Its settings live in its own database under `~/Library/Application
Support/bluebubbles-server`, so two of them can't be declared and have to be
set in the app:

- **Auto Start Method** must be "Do Not Auto Start". Its login item or its
  own LaunchAgent would race the declared one.
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
the host file turns it off, which makes the mini a LAN server like the
LXCs, whose firewalls open each service's port to the whole LAN anyway.
That's what lets Prometheus scrape it and, later, ingress route to it.

Prometheus's memory alert reads `node_memory_MemAvailable_bytes`, which
macOS's node exporter doesn't publish, so it never fires for the mini. The
disk, CPU and HostDown alerts work as on the LXCs.

## What it doesn't get yet

No routes, no backup paths, and Tailscale is still the Homebrew app rather
than the declared daemon, which is why `homelab.tailscale.enable` is off and
colmena reaches it by LAN address.

## Deploying

Merging deploys the mini like any other host: the builder reaches it by
LAN address as `shane` and runs `sudo` without a password. The first switch
had to happen on the mini, because that sudo rule is part of the system
being switched to. It goes the same way for any Mac that joins later. Build
as `shane`, since root has no key for the forge and `sudo darwin-rebuild
switch` would stall on a password for `forgejo@forge`:

```sh
nix build --out-link /tmp/mini git+ssh://forgejo@forge/shane/caboodle#darwinConfigurations.mini.system
sudo nix build --no-link --profile /nix/var/nix/profiles/system /tmp/mini
sudo /tmp/mini/sw/bin/darwin-rebuild activate
```

`nh darwin switch git+ssh://forgejo@forge/shane/caboodle -H mini` does the
same where nh is installed. `-H mini` names the config, since the hostname
is `mini-server`.

After that, `colmena apply --on mini` works from anywhere with the builder's
key. `apply-local` would also do, but it matches
the node name against the hostname, and the node is `mini` while the
hostname stays `mini-server` so the tailnet name, and Tailscale Serve for
vex-code, don't change.

## Gotchas

- The builder's key used to be restricted to `nix-daemon --stdio` on the
  mini. It's unrestricted now so colmena can deploy with it, which is the
  same trust it already has as root on every LXC.
- `deployment` attributes in `hosts/mini.nix` must be plain values. Colmena
  reads `deployment.systemType` before it evaluates the node, with the NixOS
  module path, and a value that depends on the rest of the config fails there.
- Root's `PATH` on macOS has no Nix, so colmena runs Nix from
  `/run/current-system/sw/bin`. That needs nix-darwin to manage Nix, which
  it does by default and which the Lix installer doesn't get in the way of.

## Workstation gotchas

What the workstation modules and overlays do that their code can't say.

- `nixvim` keeps its own nixpkgs pin. Upstream tests against one revision,
  and following ours breaks `vimPlugins`.
- codex and claude-code come straight from `llm-agents`' outputs, as do the
  ChatGPT and Claude desktop apps on Linux, so they match Numtide's cache.
- The project-packages overlay reads the system from `prev`, since going
  through `final.stdenv` recurses.
- Bitwarden desktop runs on Electron from `electron-nixpkgs`, a separate
  nixpkgs input so that security-sensitive runtime stays current. Upstream
  pins an older Electron 43, so the overlay rewrites `package.json` to the
  version it's given. On darwin it links its Rust outputs with lld, because
  Apple's ld from cctools 1010.6 traps on the stubs for `desktop_napi`.
- `fj` prints its first-run keys-file notice to stdout, nixpkgs captures it
  into the generated completions, and fish then runs `Could` as a command.
  The overlay deletes that line until upstream sends it to stderr.
- `sesh` builds with Go 1.26. Its build runs mockery, and mockery 3.8.0
  can't read Go 1.27's export data.
- The download tuning in `nix-settings.nix` keeps a full flake update from
  turning into a machine-wide resource spike.
- The laptop turns off Spotlight's Command+Space (symbolic hotkey 64) so
  vicinae can have it.
- The login shell stays bash on Linux and zsh on macOS, so agents and
  scripts get a POSIX shell, and an interactive one hands over to fish.
  `-c` commands, `nix develop`, `nix-shell` and a shell started from fish
  stay put. `nix develop` applies its environment after the rc file, so
  handing over would lose it. A direnv environment is already exported
  (`DIRENV_DIR`) and survives the exec, so that one does hand over.
