# Workstations

The desktop, the mini and the MacBook all import `modules/workstation`, and
the Macs add `modules/workstation/darwin`. This is what holds for all of
them. Each has its own doc too: [desktop](../desktop/README.md),
[mini](../mini/README.md) and [MacBook](../macbook/README.md).

## Switching by hand

`nrs` switches whichever machine it runs on to the forge's `main`, then
refreshes every open fish shell. It passes `--refresh`, because nix
otherwise reuses a fetch for up to an hour and switches to a stale `main`.
On a Mac it finds the node by matching the hostname against each darwin
node's `networking.hostName`.

`nrs --local` switches from the checkout at `~/Projects/personal/caboodle`
instead, which Home Manager sets as `NH_FLAKE`. Flakes only see tracked
files, so `git add` new ones first.

`nrs`'s list of Macs is generated from the hive, so adding a Mac changes
every workstation's home-manager generation.

## Switching a Mac

The MacBook's switches, and a new Mac's first one, happen on the Mac. Build
as `shane` and only elevate for the switch. Root has no key for the forge,
so `sudo darwin-rebuild switch` stalls on a password for `forgejo@forge`
when it fetches the private inputs.

```sh
nh darwin switch git+ssh://forgejo@forge/shane/caboodle -H <node>
```

or, without nh:

```sh
nix build --out-link /tmp/system git+ssh://forgejo@forge/shane/caboodle#darwinConfigurations.<node>.system
sudo nix build --no-link --profile /nix/var/nix/profiles/system /tmp/system
sudo /tmp/system/sw/bin/darwin-rebuild activate
```

A local checkout works the same way with `.` in place of the forge URL. A
new Mac's first switch asks for a password, since the passwordless sudo
rule arrives with it.

`-H` names the node because a Mac's hostname isn't its node name. That's
also why `colmena apply-local` doesn't work on a Mac: it matches the node
name against the hostname.

## Homebrew on the Macs

nix-homebrew owns `/opt/homebrew`, and `onActivation.cleanup = "uninstall"`
removes any cask or formula that isn't declared. Anything that should stay
has to be declared.

Tailscale is the Homebrew app rather than the hive's daemon, so
`homelab.tailscale.enable` is off on both Macs.

## Gotchas

- `nixvim` keeps its own nixpkgs pin. Upstream tests against one revision,
  and following ours breaks `vimPlugins`.
- codex and claude-code come straight from `llm-agents`' outputs, as do the
  ChatGPT and Claude desktop apps on Linux, so they match Numtide's cache.
- The project-packages overlay reads the system from `prev`, since going
  through `final.stdenv` recurses.
- Bitwarden desktop runs on Electron from `electron-nixpkgs`, a separate
  nixpkgs input so that security-sensitive runtime stays current. Upstream's
  `package.json` pins an exact Electron version, so the overlay rewrites it
  to the one it's given. On darwin it links its Rust outputs with lld, because
  Apple's ld from cctools 1010.6 traps on the stubs for `desktop_napi`.
- `fj` prints its first-run keys-file notice to stdout, nixpkgs captures it
  into the generated completions, and fish then runs `Could` as a command.
  The overlay deletes that line until upstream sends it to stderr.
- `sesh` builds with Go 1.26. Its build runs mockery, and mockery 3.8.0
  can't read Go 1.27's export data.
- The download tuning in `nix-settings.nix` keeps a full flake update from
  turning into a machine-wide resource spike.
- The login shell stays bash on Linux and zsh on macOS, so agents and
  scripts get a POSIX shell, and an interactive one hands over to fish.
  `-c` commands, `nix develop`, `nix-shell` and a shell started from fish
  stay put. `nix develop` applies its environment after the rc file, so
  handing over would lose it. A direnv environment is already exported
  (`DIRENV_DIR`) and survives the exec, so that one does hand over.
- The SSH aliases reach each machine by its MagicDNS name and set
  `HostKeyAlias` to the short name, so `known_hosts` keeps one key per
  machine however `HostName` is spelt.
