# Jovian-NixOS on the Steam Deck LCD

- **Question:** Can you help me do the whole Jovian thing on the deck? (From
  the follow-up: research Jovian-NixOS for the Steam Deck, LCD model, APU 0405,
  x86, including battery life, and make it a caboodle host if it holds up.)
- **Researched:** 2026-10-25, normal

The Deck as checked over SSH on 2026-10-25: SteamOS 3.7.20, kernel
`6.11.11-valve27`, board `Jupiter`, BIOS `F7A0131`, Secure Boot off, kexec
enabled (`CONFIG_KEXEC=y`, `CONFIG_KEXEC_FILE=y`, `kexec_load_disabled=0`),
16 GB RAM, 1 TB Corsair MP600 Mini NVMe, ext4 microSD on `mmcblk0`, battery
at 5.33 Ah of a 5.2 Ah design.

## Sub-questions

1. Project health: activity, channel, LCD support, kernel, cache, options: answered
2. Battery life and power management against SteamOS: answered, with no measured Jovian numbers (gap)
3. What breaks or differs from SteamOS: answered from source, nothing run on hardware
4. Install path: nixos-anywhere, Jovian's docs, disko layout, the microSD: answered

## Claims

Each claim, then its source, date and verdict.

- Active on the `development` branch: 43 commits in October 2026, 28 in September, 29 in August; the last 100 commits come from four authors.
  https://github.com/Jovian-Experiments/Jovian-NixOS/commits/development (2026-10-24): confirmed.
- No GitHub releases; the newest tag is `ethangtest20231226.1`, so it rolls on commits.
  https://github.com/Jovian-Experiments/Jovian-NixOS/tags (2026-10-24): confirmed.
- Only nixos-unstable is supported, and the flake pins nixos-unstable.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/docs/getting-started.md (2026-10-24): confirmed.
- LCD (Jupiter) is still mapped in code next to OLED (Galileo); OLED-only handling is extra, and nothing gates out the LCD.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/pkgs/jupiter-hw-support/bios-fwupd.nix (2026-10-24): confirmed in code; no docs statement of LCD support found.
- Open LCD bug #497: the gamescope session failed to start after a nixpkgs update (drmModeAtomicCommit EPERM).
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/497 (2025-03-21): confirmed open, no fix found.
- Kernel is `7.2.7-valve2` from `Jovian-Experiments/linux`, chosen by default with `jovian.devices.steamdeck.enable`.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/pkgs/linux/default.nix (2026-10-24): confirmed.
- SteamOS 3.7.8 runs Linux 6.11.
  https://www.phoronix.com/news/SteamOS-3.7.8-Stable (2025-05-22): confirmed; the Deck's own 3.7.20 also runs 6.11.11.
- The kernel builds from source; the repo configures no binary cache.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/pkgs/linux/default.nix (2026-10-24): confirmed.
- Maintainer: there is no official cache.
  https://github.com/Jovian-Experiments/Jovian-NixOS/discussions/457 (2024-12-26): unconfirmed for today; no newer statement found.
- A user built the kernel locally in about two hours; Chaotic's cache served it.
  https://discourse.nixos.org/t/steam-deck-and-jovian-nixos-flake/65573 (2025-06): unconfirmed.
- Options: `jovian.devices.steamdeck.enable`, `jovian.steam.enable`, `jovian.steam.autoStart`, `jovian.steam.user`, `jovian.steam.desktopSession` (checked against the session names), `jovian.decky-loader.enable`.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steam/autostart.nix (2026-10-24): confirmed.
- Decky Loader moved to 3.3.0 on 2026-10-18.
  https://github.com/Jovian-Experiments/Jovian-NixOS/commits/development (2026-10-19): confirmed.
- Valve LCD spec: 40 Wh battery, 2 to 8 hours of play depending on the game.
  https://www.steamdeck.com/en/tech/lcd (undated): confirmed.
- Stock SteamOS LCD test: 83 minutes worst case to 7 h 09 m best case at 50% brightness.
  https://www.pcgamer.com/valve-steam-deck-battery-life (2022-02-25): unconfirmed; one old review.
- Desktop-mode idle draw about 4.1 W with Steam running against 2.7 W without it.
  https://github.com/ValveSoftware/steam-for-linux/issues/8553 (2022-04-27): unconfirmed; user measurement.
- Jovian's steam module enables the `scx_lavd` sched_ext scheduler by default.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steam/steam.nix (2026-10-24): confirmed; power effect not measured.
- Jovian sets no CPU governor, amd-pstate, `mem_sleep`, TLP, auto-cpufreq or power-profiles-daemon itself.
  https://github.com/Jovian-Experiments/Jovian-NixOS (2026-10-24): confirmed by absence.
- Udev rules make `power1_cap`, `power_dpm_force_performance_level` and `pp_od_clk_voltage` writable, so the Steam UI sets TDP and GPU clocks without root.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/devices/steamdeck/perf-control.nix (2026-10-24): confirmed.
- steamos-manager's jupiter platform: TDP 3 to 15 W, GPU 200 to 1600 MHz, charge limit via `max_battery_charge_level`.
  https://github.com/Jovian-Experiments/steamos-manager/blob/v25.5.5/data/platforms/jupiter.toml (undated (v25.5.5)): confirmed at v25.5.5; unconfirmed for Jovian's 26.4.1 pin.
- steamos-manager writes `scaling_governor` and the GPU performance level over D-Bus.
  https://github.com/Jovian-Experiments/steamos-manager/blob/v25.5.5/src/power.rs (undated (v25.5.5)): confirmed at v25.5.5.
- vpower publishes battery state to `/run/vpower` and asks for shutdown at about 0.5%.
  https://github.com/Jovian-Experiments/vpower (undated (1.6.3)): confirmed.
- upower's critical power action is Ignore, leaving low-battery shutdown to vpower and Steam.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steam/steam.nix (2026-10-24): confirmed.
- Plasma 6 in nixpkgs turns on power-profiles-daemon by default, so PPD arrives with a Plasma session.
  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/desktop-managers/plasma6.nix (2026-10-14): confirmed; effect on the Deck untested.
- SteamOS 3.8: LCD BIOS v133 adds Memory Power Down and preliminary hibernation.
  https://steamcommunity.com/games/1675200/announcements/detail/697641379212298073 (2026-06-23): confirmed; supersedes the 2025 claim that Valve doesn't support hibernation (https://github.com/nazar256/publications/blob/main/guides/steam-deck-hibernation.md).
- Sleep drain of 20 to 25% a day (OLED, no method).
  https://github.com/nazar256/publications/blob/main/guides/steam-deck-hibernation.md (2025-03-24): unconfirmed.
- SteamOS has an 80% battery charge limit under Settings > Power.
  https://steamcommunity.com/games/1675200/announcements/detail/820329049655084701 (undated (modified 2026-06-03)): confirmed.
- Issue #537: the charge limit is missing from Steam's power settings on Jovian; a maintainer says it needs the vendor kernel and the real Steam session.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/537 (2026-06-16): unconfirmed; still open.
- Issue #456: a kernel regression stopped wake from sleep, reverted the same day.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/456 (2024-12-20): superseded by the revert.
- PR #466 reverted Bluetooth wake-on-resume commits that broke resume on LCD Decks.
  https://github.com/Jovian-Experiments/Jovian-NixOS/pull/466 (2025-01-23): confirmed.
- Issue #520: wakes seconds after sleep, closed as not Jovian's; one report blamed a Bluetooth keyboard.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/520 (2025-10-23): unconfirmed.
- Issue #416: the OLED power button sometimes doesn't suspend, likely another process holding the input device.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/416 (2025-11-02): unconfirmed; untested on LCD.
- jupiter-hw-support `20260930.1` ships LCD BIOS `F7A0133`; the Deck is on `F7A0131`.
  https://github.com/Jovian-Experiments/jupiter-hw-support/tree/jupiter-20260930.1 (2026-09-30): confirmed.
- 2023 user report: schedutil gave the best FPS, performance about 0.5 W less, amd-pstate unusable.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/15 (2023-04-12): unconfirmed.
- SteamOS 3.8 moved Plasma to 6.4.3 and fixed slower Desktop Mode performance.
  https://steamcommunity.com/games/1675200/announcements/detail/697641379212298073 (2026-06-23): confirmed; no battery figures.
- Jovian has no suspend code of its own beyond BlueZ suspend scan intervals and `HandlePowerKey=ignore`, which hands the key to powerbuttond.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steamos/bluetooth.nix (2026-10-18): confirmed.
- Fan control is `jupiter-fan-control.service`, on whenever `steamdeck.enable` is.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/devices/steamdeck/fan-control.nix (2026-10-18): confirmed.
- fancontrol loads the LCD config when DMI `board_name` is `Jupiter`.
  https://github.com/Jovian-Experiments/jupiter-fan-control/blob/20260902.1/usr/share/jupiter-fan-control/fancontrol.py (2026-09-02): confirmed; the Deck reads `Jupiter`.
- `jovian.devices.steamdeck.autoUpdate` defaults to false; true runs `jupiter-biosupdate` and `jupiter-controller-update` at boot.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/devices/steamdeck/firmware.nix (2026-10-18): confirmed.
- The Deck docs page says firmware updates are manual only.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/docs/devices/valve-steam-deck/index.md (2025-01-18): contradicted by the `autoUpdate` option in firmware.nix.
- `enableFwupdBiosUpdates` defaults on, adding a Steam Deck BIOS fwupd remote with `Keyring=none` and `ApprovalRequired=false`.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/devices/steamdeck/firmware.nix (2026-10-18): confirmed.
- The fwupd BIOS cab needs Secure Boot off (or fwupd-efi) and `OnlyTrusted=false`.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/pkgs/jupiter-hw-support/bios-fwupd.nix (2026-10-18): confirmed; Secure Boot is off on the Deck.
- Issue #547: controller firmware update failed on an old LCD; Valve regressed and fixed it upstream.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/547 (2026-07-02): unconfirmed; still open.
- Steam is Valve's client with a Deck bootstrap pinned to `20251031.0`.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/pkgs/steam/unwrapped.nix (2026-10-18): confirmed.
- The beta channel self-updated to the 64-bit SteamRT3 client around 2026-10-15 and broke time zones.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/595 (2026-10-17): unconfirmed; stable not covered.
- `holo-update` and `holo-select-branch` are stubs: OS updates are NixOS generations and the only branch is main.
  https://github.com/Jovian-Experiments/Jovian-NixOS/tree/development/pkgs/jovian-stubs (2026-10-19): confirmed.
- `holo-firmware-update` is a stub, so a BIOS update from the Deck UI does nothing.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/pkgs/jovian-stubs/holo-firmware-update (2026-10-18): confirmed.
- Switch to Desktop needs `jovian.steam.desktopSession` set to a real session; the docs example is Plasma 6.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/docs/steam.md (2026-10-18): confirmed.
- Issue #586: a gamescope desktop session fails because steamos-manager rejects session names containing "gamescope".
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/586 (2026-09-26): confirmed; open.
- Audio uses Valve's DSP config through pipewire filter-chain and an ALSA UCM override.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/devices/steamdeck/sound.nix (2026-10-18): confirmed in config only.
- Decky Loader is off by default, runs as root, plugins run as `decky`, state in `/var/lib/decky-loader`.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/decky-loader.nix (2026-10-18): confirmed.
- Decky needs Steam's CEF remote-debugging file, which Jovian doesn't create; issue #460 has a user workaround.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/460 (2025-10-23): confirmed; open.
- Bluetooth uses SteamOS's BlueZ settings when `jovian.steam.enable` is on.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steamos/bluetooth.nix (2026-10-18): confirmed.
- SD cards auto-mount on insertion through jupiter-hw-support's udev rules when `jovian.steam.enable` is on.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steamos/automount.nix (2026-10-18): confirmed.
- Formatting an SD card from the Deck UI is unmerged (PR #418); an ext4 card shows in Steam once a library is made on it in desktop mode.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues/321 (2025-03-19): confirmed for the PR; unconfirmed for the library step.
- Other open issues from the last six months: #570 gamescope crash in desktop mode, #543 build failure, #490 compat layers, #244 DTM TA warning.
  https://github.com/Jovian-Experiments/Jovian-NixOS/issues (2026-10-24): confirmed as a list.
- SteamOS 3.7.25 and 3.8.5 beta released in May 2026.
  https://www.gamingonlinux.com/2026/05/steamos-3-7-25-and-3-8-5-beta-released-bug-fixes-and-better-dgpu-video-memory-management (2026-05): unconfirmed; secondary.
- nixos-anywhere kexecs into its own installer when the target isn't a NixOS installer.
  https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/no-os.md (2026-05-26): confirmed.
- Target needs x86-64 Linux with kexec, root or passwordless sudo, tar and cpio; it stages under `$HOME/kexec`.
  https://nix-community.github.io/nixos-anywhere/quickstart.html (2025-12-23): confirmed; the Deck meets all of it.
- RAM needed: 1 GB in the README, 1.5 GB in requirements.md.
  https://github.com/nix-community/nixos-anywhere/blob/main/docs/requirements.md (2025-07-09): the docs disagree; the Deck has 16 GB.
- Valve's neptune kernels carry `CONFIG_KEXEC=y`.
  https://github.com/neptune-mirror/linux-neptune (2024-01-24): confirmed on the Deck itself.
- No reports found of nixos-anywhere on a Steam Deck.
  GitHub issue search (2026-10-25): unconfirmed (absence).
- kexec changes the host SSH key, so the old `known_hosts` entry needs clearing.
  https://nix-community.github.io/nixos-anywhere/quickstart.html (2025-12-23): confirmed.
- Jovian says install however you like and ships no installer ISO; `support/test-iso` is not for installing.
  https://jovian-experiments.github.io/Jovian-NixOS/getting-started.html (2024-09-05): confirmed.
- Boot menu: power off, hold Volume Down, tap Power.
  https://github.com/Jovian-Experiments/Jovian-NixOS/blob/main/docs/devices/valve-steam-deck/index.md (2025-01-18): confirmed.
- An external display is needed to boot the installer USB.
  https://heywoodlh.io/nixos-steamdeck (undated): superseded: issue #39 closed 2023-10-23 after nixpkgs PR #249218.
- disko reference layout: GPT, 500M vfat ESP at `/boot` with `umask=0077`, ext4 root at 100%, by-id device path.
  https://github.com/nix-community/disko/blob/master/example/simple-efi.nix (2024-10-02): confirmed.
- disko reformats the whole declared disk and doesn't do dual boot, so SteamOS goes.
  https://github.com/nix-community/disko/blob/master/docs/quickstart.md (2025-01-12): confirmed.
- `disko-install` only writes NVRAM boot entries with `--write-efi-boot-entries`.
  https://github.com/nix-community/disko/blob/master/docs/disko-install.md (2025-08-18): confirmed; nixos-anywhere's behaviour not checked.
- SteamOS's loader is `\EFI\steamos\steamcl.efi` on the first NVMe partition.
  https://foosel.net/til/2023-11-25-how-to-fix-grub-after-steamos-update (2023-11-25): confirmed on the Deck by `efibootmgr`.
- NixOS has `zramSwap.enable`, `memoryPercent` and `algorithm`.
  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/config/zram.nix (undated): confirmed.
- disko only touches disks declared in `disko.devices`, so the microSD is left alone.
  https://github.com/nix-community/disko/blob/master/docs/quickstart.md (2025-01-12): confirmed.

## Gaps

- No measured battery life or sleep drain on Jovian for the LCD, and none for
  a Plasma session against Gaming Mode. The only LCD numbers are from 2022 on
  stock SteamOS, so the comparison has to be measured on this Deck.
- Whether the 7.2 kernel and issue #497 bite on this LCD needs a boot on the
  hardware.
- Whether the charge limit (#537) shows up needs a boot on the hardware.
- Valve's SteamOS recovery page renders with JavaScript and couldn't be read,
  so the recovery-image steps weren't checked. A wipe of the NVMe removes
  SteamOS, so getting it back means that image on a USB stick.
- Whether nixos-anywhere writes an NVRAM boot entry wasn't checked.
- How fast stable-channel Steam client updates land on Jovian wasn't traced.
