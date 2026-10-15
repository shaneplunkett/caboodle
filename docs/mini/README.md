# The Mac mini

The mini is a Mac server in the hive, deployed on merge like the LXCs.
Colmena runs from a fork that can deploy darwin nodes until upstream merges
it. The mini is also the builder's darwin remote builder, so the PR build
check builds every Mac on it. It's a workstation too, so
[docs/workstation](../workstation/README.md) covers what it shares with the
desktop and the MacBook.

vex-brain's vex-sync runs as daemons rather than home-manager agents, so
sync runs from boot with nobody logged in.

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
it's off, which makes the mini a LAN server like the LXCs, whose firewalls
open each service's port to the whole LAN anyway. That's what lets
Prometheus scrape it.

Prometheus's memory alert reads `node_memory_MemAvailable_bytes`, which
macOS's node exporter doesn't publish, so it never fires for the mini. The
disk, CPU and HostDown alerts work as on the LXCs.

## Deploying

Merging deploys it: the builder reaches it as `shane` and runs `sudo`
without a password. Tailscale is the Homebrew app, so colmena uses its LAN
address. `colmena apply --on mini` works from anywhere with the builder's
key.

The first switch has to happen on the mini, because the passwordless sudo
rule is part of the system being switched to. Use the recipe in
[docs/workstation](../workstation/README.md#switching-a-mac) with
`-H mini`. The hostname stays `mini-server` so the tailnet name, and
Tailscale Serve for vex-code, don't change.

## Gotchas

- `deployment` attributes in `hosts/mini.nix` must be plain values. Colmena
  reads `deployment.systemType` before it evaluates the node, with the NixOS
  module path, and a value that depends on the rest of the config fails there.
- Root's `PATH` on macOS has no Nix, so colmena runs Nix from
  `/run/current-system/sw/bin`. That needs nix-darwin to manage Nix, which
  it does by default and which the Lix installer doesn't get in the way of.
