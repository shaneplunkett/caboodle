# The desktop

The NixOS desktop is a node in the hive like the LXCs and the mini, but
merging never deploys it. It has no deploy tags, so the PR build check
builds it on the builder, which fills the cache, and Shane switches it on
the desktop when she's ready. See [amdgpu-crash-dumps](amdgpu-crash-dumps.md)
for the GPU crash collector it runs.

## What the hive gives it

`nixosDefaults` in `flake.nix`, the same as every NixOS host:
`modules/nixos.nix` (Nix settings, nh's weekly clean, node exporter wired
to `homelab.monitoring`), agenix with no secrets asked for, the backup
module with no paths so it does nothing, and alloy, which ships the
journal to Loki as `desktop` while it's on. It isn't an LXC, so it doesn't
get `modules/lxc.nix`.

It's a machine Shane sits at, so it imports `modules/workstation`, which
the Macs share, and `modules/workstation/nixos`: home-manager and
catppuccin's NixOS modules, audio, Docker, locale, the Unraid shares, and
Shane's user with her sudo rules. The host file points home-manager at
`home/shane/home.nix` and picks Noctalia as the shell. Its nixpkgs is
`workstationPkgs`, with the overlays the mini gets.

`homelab.monitoring.enable` is off, so Prometheus doesn't scrape it and a
powered-off desktop doesn't page anyone. Its logs still reach Loki.

`homelab.tailscale.enable` is off too. The hive's Tailscale module joins
with an agenix OAuth secret, and the desktop's host key isn't one of its
recipients. The desktop runs Tailscale from its own
`hosts/desktop/modules/networking.nix` instead, with MagicDNS through
resolved. Without resolved, tailscaled overwrites `/etc/resolv.conf` and
fights NetworkManager, which is what broke DNS here in March. With it,
tailscaled registers `100.100.100.100` on `tailscale0`, which answers
`.ts.net` names and forwards the rest to the tailnet's resolvers, Blocky on
dns1 and dns2. If Tailscale is down, the LAN link's DHCP gives the same two.
`FallbackDNS` is empty so resolved never goes round them to a public
resolver, and its mDNS is off because Avahi already has port 5353.

## Switching

Wait for the PR's `build (desktop)` check to go green first, so the switch
downloads what the builder made instead of compiling it here. Then, from
the caboodle checkout on the desktop:

```sh
colmena apply-local --sudo
```

`apply-local` finds the node by hostname, and both are `desktop`. `--sudo`
runs colmena's `nix-env --set` and `switch-to-configuration` through sudo.

`nh os switch` does the same job with nh's build tree and diff. Home
Manager sets `NH_FLAKE` to `~/Projects/personal/caboodle`, so it needs no
arguments. `nrs` is a fish wrapper around it that also refreshes every
open fish shell afterwards. Flakes only see tracked files, so `git add`
new ones before either.

Colmena can't deploy the desktop over SSH. Root has no keys there and sshd
refuses root logins.

Home Manager is part of the system switch. `home-manager switch` or
running a generation's `activate` by hand fires its activation hooks
outside a switch, so only do that when Shane asks for exactly that.

Switching is passwordless. The sudo rules in
`modules/workstation/nixos/user.nix` allow exactly the commands nh and
colmena elevate. If either prompts for a password, look at the sudo
command it ran rather than assuming Shane has to type it.

## What replaced nix-config's tooling

nix-config's `scripts/remote.sh [eval|build|switch] [host]` synced the
working tree, uncommitted changes and all, to whichever machine did the
work and ran nh there. Eval and build went to an always-on builder for the
host's platform, and switch ran on the host itself. Its dev shell wrapped
it as `switch`, `build` and `evaluate`, and `nrs` switched the current
machine from `~/nix-config`.

Here the PR check builds every host on the builder, the desktop included.
Locally, `colmena build --on desktop` or `nix build .#hydraJobs.desktop`
builds it on the desktop, and the switch is one of the commands above.
Nothing switches the desktop from another machine any more.

## Gotchas

- nh's clean keeps two generations, as on the LXCs. nix-config kept a
  week, and systemd-boot lists up to ten, so after the weekly clean the
  older boot entries are gone.
- NixOS modules get `palette` and `typography` from
  `modules/workstation/nixos`, and `shell` from the host file, as module
  arguments. A module can take them as function arguments but can't use
  them in `imports`, since module arguments aren't known yet when imports
  are resolved.
- Noctalia keeps its own nixpkgs pin. Following ours would change its
  hashes and miss its Cachix cache, so it would build locally. Hyprland
  comes from our nixpkgs, so the NixOS cache has it.
- The SSH aliases in `home/shane/modules/common/ssh.nix`, which the Macs
  share, reach each machine by its MagicDNS name and set `HostKeyAlias` to
  the short name, so `known_hosts` keeps one key per machine however
  `HostName` is spelt.
- `noctalia` tracks upstream's `cachix` branch, which trails main to the
  newest commit their CI has cached.
- `noctalia-plugins` is only a source tree. Noctalia reads its `plugins/`
  directory as a path source, so shipping a plugin change is
  `nix flake update noctalia-plugins`.
- A newly installed app's icon shows as a magenta checkerboard in Noctalia
  until the shell restarts: `kill` the quickshell process, then
  `hyprctl eval 'hl.exec_cmd("noctalia-shell")'`.
- `gvfs` uses the plain package. COSMIC Files mounts drives and network
  shares through GIO, and the module's default is GNOME's build with
  online accounts, which it doesn't need.
- gnome-keyring is the Secret Service for apps and for Noctalia's own
  credentials. greetd's PAM stack includes `login`, which unlocks the
  keyring with the login password, so gcr's prompt only appears if that
  unlock fails.
- `at-spi2-core` is on for T3 SnapShots' "Include app text". Without it
  NixOS sets `NO_AT_BRIDGE=1` and apps publish no text.
