# The MacBook

The MacBook is a node in the hive, evaluated with nix-darwin like the mini.
Every pull request builds it on the mini, the builder's darwin remote
builder, but nothing deploys it. Shane switches it by hand on the laptop.

## What the hive gives it

The same `darwinDefaults` as the mini: Nix settings and the homelab cache,
weekly GC, fish, Shane as the primary user with the builder's key, and
passwordless sudo for her. It imports `modules/workstation` and
`modules/workstation/darwin` like the mini, plus
`modules/workstation/darwin/laptop` for the apps and settings only the
laptop wants. Its home-manager config is `home/shane/homemac.nix`, which
brings OmniWM and vicinae, and its nixpkgs is `workstationPkgs`, the same
as the mini's.

The hive sets defaults and the laptop overrides them. `modules/darwin` turns
automatic macOS updates off with `mkDefault`, since the mini shouldn't
restart under its services, and the laptop turns them back on. The laptop
also keeps the application firewall on, in stealth mode, where the mini
turns it off to act as a LAN server.

## Why it's never deployed on merge

It's a laptop. It's asleep or off the LAN much of the time, so a deploy on
merge would fail more often than not, and a switch landing while Shane is
working would swap apps and Homebrew casks out from under her. So its
`deployment.tags` is empty, which keeps it out of `@deploy-on-merge`, and the
build check still proves every merge builds for it.

For the same reason it has no `homelab.lanAddress`. Anything that walks the
whole hive (Blocky's client names, the builder's SSH config, the `network`
output Terraform reads) skips a host without one. A host that turns on
monitoring, routes or port forwards has to have one, and evaluation fails
with an assertion if it doesn't. Monitoring is off, since a sleeping laptop
would trip HostDown all day, and Tailscale is still the Homebrew app, as on
the mini.

## Switching

Build as `shane` and only elevate for the switch, the same as the mini.
Root has no key for the forge, so `sudo darwin-rebuild switch` stalls on a
password for `forgejo@forge` when it fetches the private inputs:

```sh
nh darwin switch git+ssh://forgejo@forge/shane/caboodle -H macbook
```

or, without nh:

```sh
nix build --out-link /tmp/macbook git+ssh://forgejo@forge/shane/caboodle#darwinConfigurations.macbook.system
sudo nix build --no-link --profile /nix/var/nix/profiles/system /tmp/macbook
sudo /tmp/macbook/sw/bin/darwin-rebuild activate
```

A local checkout works the same way with `.` in place of the forge URL.

The first switch from nix-config asks for a password (or Touch ID).
nix-config's sudo rule only let through nh's two elevated commands, run
against nh's out-link in its temp dir, so the commands above need the
password, and so does nh if its commands don't match the rule exactly.
Once that switch lands, the hive's passwordless sudo applies.

`-H macbook` names the config, since the node is `macbook` and the hostname
stays `Shanes-MacBook-Pro`, so the tailnet name doesn't change. That's also
why `colmena apply-local` won't work: it matches the node name against the
hostname.

## What wasn't carried from nix-config

- The `yt-dlp` overlay that dropped `secretstorage` on darwin. Nothing on
  the Mac pulls in yt-dlp. If something does later, the overlay goes into
  `pkgs/overlays.nix`.
- nix-homebrew's `autoMigrate`. Homebrew on the laptop was already migrated
  under nix-homebrew by nix-config, so there's nothing left to migrate.
- nix-config's sudo rule for nh's commands, replaced by the hive's
  passwordless sudo for Shane.

## Gotchas

- The `nrs` fish function switches from `NH_FLAKE`, the homelab checkout
  at `~/Projects/personal/homelab`, so it needs a clone there. It matches
  the Mac's hostname against each darwin node's `networking.hostName` as
  well as its name, which is how `Shanes-MacBook-Pro` finds `macbook`.
- The `nrs` function's list of darwin hosts is generated from the hive, so
  adding a Mac changes every Mac's home-manager generation, the mini's
  included.
