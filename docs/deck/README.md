# The Steam Deck

The Deck is an LCD model running NixOS through
[Jovian-NixOS](https://github.com/Jovian-Experiments/Jovian-NixOS). It's a
host in the hive like the desktop: the PR build check builds it on the
builder, and merging never deploys it. It boots into Game Mode, and Switch to
Desktop opens Plasma. Why Jovian, and what it does and doesn't do, is in
[the research](../research/2026-10-25-jovian-steam-deck.md).

Monitoring is off, since the Deck is off or away more than it's on. The
hive's Tailscale is off for the same reason as the desktop's: it joins with
an agenix secret the Deck's host key can't read. `services.tailscale` runs
instead, and joins once with `sudo tailscale up`.

## Switching

`nrs` doesn't work on the Deck: the flake's private inputs need the forge
key, which the Deck doesn't have, and evaluating the hive there would take
gigabytes. Switch it from the desktop instead. Once the PR's
`build (deck)` check is green, the builder has put the system in the cache,
so the Deck downloads it and nothing builds:

```sh
p=$(nix eval --raw .#hydraJobs.deck.outPath)
ssh deck "sudo nix-env --profile /nix/var/nix/profiles/system --set $p && sudo $p/bin/switch-to-configuration switch"
```

Sudo needs no password on the Deck, as on SteamOS. SSH only takes Shane's
key, so that's only reachable with the Deck in hand or her key.

## Installing

nixos-anywhere installs it over SSH from SteamOS, with the Deck on the dock
and ethernet in a main LAN port. The kexec installer only brings up wired
networking, so Wi-Fi can't carry the install, and a port on the IoT VLAN
leaves the installer where the desktop can't reach it.

Before the wipe:

- Back up `/home/deck`. Proton keeps saves in each prefix's
  `pfx/drive_c/users/steamuser`, which is a few MB of the prefixes' tens of
  GB. The installed games download again.
- Make the host key in a private temp dir, under `etc/ssh/`, and add its
  public half to `modules/agenix/host-keys.nix`. Copy SteamOS's
  `/etc/NetworkManager/system-connections/` next to it, so the Deck joins
  Wi-Fi on its first boot.
- SteamOS has no `cpio`, which nixos-anywhere needs, but it has `bsdcpio`.
  `sudo steamos-readonly disable`, then link `/usr/bin/bsdcpio` to
  `/usr/local/bin/cpio`.

Then:

```sh
nix run --inputs-from . nixpkgs#nixos-anywhere -- --flake .#deck \
  --target-host deck@<deck-ip> --extra-files <temp-dir>
```

- The installer can come up on a different DHCP address from SteamOS's,
  and nixos-anywhere keeps knocking on the old one. Find the new one with
  `nmap -p22 --open` across the LAN (it lets in root with Shane's key), stop
  nixos-anywhere, and rerun it against `root@<new-ip>` with
  `--phases disko,install,reboot`.
- The screen stays black while the installer runs.
- disko only touches `nvme0n1`. The microSD is a separate disk and keeps
  its games.
- If it goes wrong, Valve's recovery image, written to a USB stick, puts
  SteamOS back. A copy is on the NAS under `games/dumps/steamos-recovery`.

## Gotchas

- BIOS updates don't run from the Steam UI, since Jovian stubs
  `holo-firmware-update`. Run `sudo jupiter-biosupdate` instead.
- Steam's 80% battery charge limit doesn't show up yet (Jovian issue #537).
- Jovian has no binary cache, so the Valve kernel builds from source on the
  builder.
- An ext4 SD card mounts by itself, but Steam only lists it once it's added
  as a library from Desktop Mode.
- If the touchscreen goes dead, the touch chip has stuck powered off: its
  ACPI node at `/sys/bus/i2c/devices/i2c-FTS3528:00/firmware_node` reads
  `D3hot`, and binding `i2c_hid_acpi` to it fails with "No such device or
  address". A shut down doesn't reset it. Battery Storage in the BIOS
  (Volume Up and Power, then Power) does: unplug the Deck first, and plug
  the charger in to wake it. It was dead on SteamOS too before the switch.
