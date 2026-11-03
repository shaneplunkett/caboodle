# The Steam Deck

The Deck is an LCD model running NixOS through
[Jovian-NixOS](https://github.com/Jovian-Experiments/Jovian-NixOS). It's a
host in the hive like the desktop, and nothing deploys it: a merge builds it
on the runner and the Deck pulls the result from the cache. It boots into Game
Mode, and Switch to Desktop opens Plasma. Jovian only supports nixos-unstable and has no
releases, so it moves with whatever commit the lock holds. It brings
Valve's kernel, Steam client, fan control and power controls, and stubs
SteamOS's own OS updates, since those are NixOS generations here.

Monitoring is off, since the Deck is off or away more than it's on. The
hive's Tailscale is off for the same reason as the desktop's: it joins with
an agenix secret the Deck's host key can't read. `services.tailscale` runs
instead, and joins once with `sudo tailscale up`.

## Switching

A merge leaves the Deck's closure in the [cache](../pve/cache.md), and its
profile there names the newest one. Read that name and hand it to the Deck,
which fetches the closure from the cache itself, so nothing compiles on the
Deck and no other machine's store is involved. From anything holding Shane's
key:

```sh
p=$(ssh root@cache readlink -f /nix/var/nix/profiles/per-host/deck)
ssh deck "sudo nix-env --profile /nix/var/nix/profiles/system --set $p && sudo $p/bin/switch-to-configuration switch"
```

On the Deck itself, with her key there, it's the same without the `ssh deck`:

```sh
p=$(ssh root@cache readlink -f /nix/var/nix/profiles/per-host/deck)
sudo nix-env --profile /nix/var/nix/profiles/system --set "$p" && sudo "$p/bin/switch-to-configuration" switch
```

Each path prints `copying path '...' from 'http://cache.home.arpa:5000'`, and
a closure the Deck already has prints nothing. Then
`nixos-version --configuration-revision` gives the commit it's on.

- **The merge's run hasn't pushed yet.** The profile still names the last
  closure pushed, so this switches to that commit and does no harm. To see
  which commit the profile holds before switching:
  `ssh root@cache "$p/sw/bin/nixos-version" --configuration-revision`.
- **The cache is down, or the Deck can't reach it.** `nix-env` tries each
  substituter, fails with `path '...' is required, but there is no substituter
  that can build it`, and the `&&` stops there, so the Deck stays as it was.
  The Deck only has the output's name, with no derivation to build from, so it
  can't fall back to compiling. A Deck away from home needs to accept
  Tailscale's routes to reach the address.
- **`nrs` is the other way in**, for a Deck without her key. It evaluates this
  one host, about 4 GB of heap, which needs
  [the inputs token](../workstation/README.md#the-inputs-token) and enough
  memory free, so not with a game running. It then pulls the same closure, and
  it does have a derivation, so with the cache down it compiles what no other
  cache has, the Valve kernel included. It hasn't been tried on the Deck yet.

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
  The boot menu is Volume Down held while tapping Power, from off.

## Gotchas

- BIOS updates don't run from the Steam UI, since Jovian stubs
  `holo-firmware-update`. Run `sudo jupiter-biosupdate` instead.
- Steam's 80% battery charge limit doesn't show up yet (Jovian issue #537).
- Jovian has no binary cache, so the Valve kernel builds from source on the
  runner whenever it changes.
- `jovian.steam.desktopSession` has to name a real session, and
  steamos-manager rejects any session whose name contains "gamescope"
  (Jovian issue #586).
- Decky Loader is off. Turning it on isn't enough by itself: it needs Steam's
  CEF remote-debugging file, which Jovian doesn't create (Jovian issue #460
  has a workaround).
- An ext4 SD card mounts by itself, but Steam only lists it once it's added
  as a library from Desktop Mode.
- If the touchscreen goes dead, the touch chip has stuck powered off: its
  ACPI node at `/sys/bus/i2c/devices/i2c-FTS3528:00/firmware_node` reads
  `D3hot`, and binding `i2c_hid_acpi` to it fails with "No such device or
  address". A shut down doesn't reset it. Battery Storage in the BIOS
  (Volume Up and Power, then Power) does: unplug the Deck first, and plug
  the charger in to wake it. It was dead on SteamOS too before the switch.
- In Desktop Mode, the trackpads are a mouse only until an app opens the
  controller through SDL, as Eden does, which turns the kernel's mouse
  mode off. SteamOS keeps Steam running on the desktop to drive them, so
  Plasma starts `steam -silent` too. KWin asks before letting Steam move the
  pointer, so `XwaylandEisNoPrompt` turns that prompt off (Jovian issue
  #519).
- Plasma's screen locker is off. Shane's user has no password, so a lock
  screen could only lock her out.
- The speaker amps, two CS35L41s on SPI (`spi-VLV1776:00` and `:01`), fail
  to wake from runtime hibernate on this kernel: dmesg shows "Wake failed,
  re-enter hibernate" and "Timed out waking device", their
  `power/runtime_status` reads `error`, and PipeWire falls back to Dummy
  Output. Only a reboot clears it, so a udev rule sets their
  `power/control` to `on` and they never hibernate.
- Games launched from Steam see Steam's virtual pad (`28de:11ff`, "Microsoft
  X-Box 360 pad 0") instead of the Deck's controller. Eden and Azahar bind
  controls by the pad's SDL GUID, so the Deck sets their player 1 to it on
  every switch, using EmuDeck's mappings, through
  `modules/workstation/nixos/emulator-controls.py`. The two GUIDs differ because Azahar's
  SDL adds a checksum. An emulator writes its config when it closes, so it
  has to be closed during the switch or it puts its old controls back.
