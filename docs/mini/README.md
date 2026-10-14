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

## The firewall

The macOS application firewall lets signed apps accept connections and
silently drops the rest, and anything Nix builds is only ad-hoc signed. So
the host file turns it off, which makes the mini a LAN server like the
LXCs, whose firewalls open each service's port to the whole LAN anyway.
That's what lets Prometheus scrape it and, later, ingress route to it.
`docs/research/mini-server.md` has the alternatives that were considered.

Prometheus's memory alert reads `node_memory_MemAvailable_bytes`, which
macOS's node exporter doesn't publish, so it never fires for the mini. The
disk, CPU and HostDown alerts work as on the LXCs.

## What it doesn't get yet

No routes, no backup paths, and Tailscale is still the Homebrew app rather
than the declared daemon, which is why `homelab.tailscale.enable` is off and
colmena reaches it by LAN address.

The vex-sync daemons and the vex-code agent are still nix-config's. A switch
from the hive removes the vex-sync daemons, since the previous system
declared them and this one doesn't; vex-code is a home-manager agent and
keeps running until the next reboot. Homebrew isn't managed from here, so
the casks nix-config installed stay put.

BlueBubbles is on the mini too, as a login agent, and no config declares it.
It's how Shane uses iMessage from NixOS, so it stays. It was installed by
hand rather than through Homebrew, and Homebrew won't install a cask over an
app it didn't put there. When the hive takes over Homebrew and declares
`bluebubbles`, first run `brew install --cask --adopt bluebubbles` on the
mini, or bin the app and let brew reinstall it. Its config and pairing live
under `~/Library` and survive either.

## Deploying

Merging deploys the mini like any other host: the builder reaches it by
LAN address as `shane` and runs `sudo` without a password. The first switch
had to happen on the mini, because that sudo rule is part of the system
being switched to. It goes the same way for any Mac that joins later. Build
as `shane`, since root has no key for the forge and `sudo darwin-rebuild
switch` would stall on a password for `forgejo@forge`:

```sh
nix build --out-link /tmp/mini git+ssh://forgejo@forge/shane/homelab#darwinConfigurations.mini.system
sudo nix build --no-link --profile /nix/var/nix/profiles/system /tmp/mini
sudo /tmp/mini/sw/bin/darwin-rebuild activate
```

`nh darwin switch git+ssh://forgejo@forge/shane/homelab -H mini` does the
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
