# The Mac mini

The mini is a node in the hive like the LXCs, evaluated with nix-darwin and
deployed by colmena, which runs from a fork that can deploy darwin nodes
until upstream merges it. The PR build check builds its system on the mini
itself, since it's also the builder's darwin remote builder.

## What the hive gives it

`darwinDefaults` in `flake.nix` is the Mac counterpart of `nixosDefaults`:
Nix settings and the homelab cache, weekly GC, fish, Shane as the primary
user with the builder's key, and the macOS application firewall as it was
under nix-config. The host file adds the deploy settings, auto-login, and
staying awake.

## What it doesn't get yet

Nothing that reaches it over the network, because the application firewall
drops incoming connections to anything Nix built. Until that's decided
(`docs/research/mini-server.md` has the options), the mini has
`homelab.monitoring.enable = false`, no routes, no backup paths, and runs
Tailscale as the Homebrew app rather than the declared daemon, which is why
`homelab.tailscale.enable` is off and colmena reaches it by LAN address.

The vex-sync daemons and the vex-code agent are still nix-config's. A switch
from the hive removes the vex-sync daemons, since the previous system
declared them and this one doesn't; vex-code is a home-manager agent and
keeps running until the next reboot. Homebrew isn't managed from here, so
the casks nix-config installed stay put.

## Deploying

The mini isn't tagged `deploy-on-merge`, so merging builds it and nothing
more. The first switch has to happen on the mini, because colmena deploys
as `shane` and runs `sudo` without a password, and the sudo rule allowing
that is part of the system being switched to:

```sh
sudo darwin-rebuild switch --flake git+ssh://forgejo@forge/shane/homelab#mini
```

After that, `colmena apply --on mini` works from anywhere with the builder's
key, and the tag can go back on. `apply-local` would also do, but it matches
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
