# Workstations

The desktop, the Deck, the mini and the MacBook all import
`modules/workstation`. The desktop and the Deck add
`modules/workstation/nixos`, and the Macs add `modules/workstation/darwin`.
This is what holds for all of them. Each has its own doc too:
[desktop](../desktop/README.md), [Deck](../deck/README.md),
[mini](../mini/README.md) and [MacBook](../macbook/README.md).

## Switching by hand

`nrs` switches whichever machine it runs on to the forge's `main`, then
refreshes every open fish shell. It passes `--refresh`, because nix
otherwise reuses a fetch for up to an hour and switches to a stale `main`.
On a Mac it finds the host by matching the hostname against each darwin
host's `networking.hostName`.

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
nh darwin switch git+ssh://forgejo@forge/shane/caboodle -H <host>
```

or, without nh:

```sh
nix build --out-link /tmp/system git+ssh://forgejo@forge/shane/caboodle#darwinConfigurations.<host>.system
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

## Emulation

The desktop and the Deck share `modules/workstation/nixos/emulation.nix`, so
they run the same emulators against the same folder layout. Each host sets
`homelab.emulation.root`, and `~/Emulation` links to it: the NAS's `games`
share on the desktop, the SD card's `Emulation` folder on the Deck, so the
Deck plays offline. Each of `roms`, `saves` and `bios` has a folder per
system: `gb`, `gbc`, `gba`, `nds`, `psp`, `switch`, `n3ds` and `psvita`.

Emulators rewrite their own settings files, so Nix doesn't own those.
Home Manager links each emulator's save folder and keys into `~/Emulation`
instead, and the rest stays settable in the emulator's menus.

- RetroArch plays Game Boy, GBC and GBA through Gambatte and mGBA, and DS
  through melonDS DS. It has one saves setting, so a content-directory
  override per core and system (`config/<core>/<system>.cfg`) sends a game
  from `roms/gba` to `saves/gba`. It names saves `.srm`, which is the same
  bytes as a cart dump's `.sav`, so a dump needs renaming to load.
  RetroArch's shared autoconfig has no profile for Steam's virtual pad
  (`28de:11ff`, what a game launched from Steam sees), so the module adds
  one alongside the shared profiles.
- PPSSPP plays PSP. Its default map expects the shoulders on button codes
  its SDL driver never sends (it sends 192 for R and 193 for L), so every
  switch sets `L` and `R` in `controls.ini`, through `emulator-controls.py`.
  PPSSPP saves that file when it quits, so it has to be closed during the
  switch.
- Eden and Ryubing both play Switch, since a game that breaks on one often
  runs on the other. Their saves have different layouts, so `saves/switch`
  has a folder for each. Both read `prod.keys` and `title.keys` from
  `bios/switch`. Firmware installs from `bios/switch/firmware-*` through
  each emulator's menu, and updates and DLC live in `roms/switch/updates`.
  Eden files each save under a user profile's ID, and a fresh install
  makes a new profile, so it calls the copied saves orphaned. Copying
  `nand/system/save/8000000000000010/su/avators/profiles.dat` from a machine
  that already has the saves gives it the same profile.
  The keys and firmware come from Shane's own Switch: Lockpick_RCM writes
  the keys to its SD card, and nxdumptool's "dump system update" sends the
  firmware over USB.
- Azahar plays 3DS and reads `bios/n3ds/boot9.bin`. Its saves, and Vita3K's,
  aren't linked yet, since neither has been tried with these games.
- Steam ROM Manager puts the games in Steam, with a parser per system.
  Home Manager rewrites its `userConfigurations.json` on every switch, so a
  parser change goes in the Nix, not the app. Run it after adding games,
  with Steam closed. It fetches its presets from GitHub's API without
  signing in, which allows 60 calls an hour per home connection, and it
  shows "fatal error" when that runs out. `curl api.github.com/rate_limit`
  shows when it resets.
- The saves on the NAS and on the Deck are separate copies, so copy them
  across by hand until something syncs them.
- `fusee-nano` is patched to wait 250 ms between sending the exploit's
  oversized control transfer and cancelling it. Upstream cancels at once,
  and on the 20 Gbps USB-C controller the cancel often beats the request
  onto the wire, so the Switch stays in RCM with a black screen while the
  tool still prints `Smashed the stack: 0`. Unpatched, it failed six times
  in a row there, and the patched build worked first time.
- The rules in `emulation.nix` give the logged-in user the Switch in RCM
  (`0955:7321`) and nxdumptool's USB mode (`057e:3000`), so `fusee-nano`
  and nxdumptool's `nxdt_host.py` run without sudo.
- They ship as a udev package named `70-…` instead of `extraRules`, which
  lands in `99-local.rules`. systemd's `73-seat-late.rules` applies
  `uaccess` before that, so a tag added there does nothing.

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
