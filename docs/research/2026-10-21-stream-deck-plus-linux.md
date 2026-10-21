# Stream Deck + on Linux

- **Question:** Can you check the current state of using streamdecks on linux? Particularly the + version with the volume knobs n things? Have one thats been sitting on my desk collecting dust since I moved of windows and last time I looked it as bad haha
- **Researched:** 2026-10-21, normal

## Sub-questions

1. Which Linux apps support the Stream Deck + (dials, touch strip), and how maintained is each?: answered
2. Can the dials control PipeWire volume (default sink, per-app, mute on press, level on the strip)?: answered
3. How do the apps install and run on NixOS with Hyprland (packages, modules, udev, Wine, Wayland limits)?: answered
4. Has Elgato shipped or announced official Linux support?: answered

## Claims

Each claim, then its source, date and verdict.

- The Stream Deck + has 8 keys, 4 dials and a touch strip.
  https://www.elgato.com/us/en/p/stream-deck-plus (undated): confirmed.
- Elgato's Stream Deck software system requirements list Windows 11 and macOS 13+ only, no Linux.
  https://help.elgato.com/hc/en-us/articles/34512594204049-Elgato-Stream-Deck-Software-System-Requirements (2026-06-25): confirmed.
- Stream Deck 7.6 release notes (latest) have no Linux mention.
  https://help.elgato.com/hc/en-us/articles/51156609278737-Elgato-Stream-Deck-7-6-Release-Notes (2026-09-22): confirmed.
- The Stream Deck SDK manifest supports only `mac` and `windows`.
  https://docs.elgato.com/streamdeck/sdk/references/manifest (undated): confirmed.
- Elgato's GitHub org has no Linux repo.
  https://github.com/orgs/elgatosf/repositories (undated): confirmed.
- No 2025-2026 announcement of official Linux support.
  tvly news search (2026-10-21): confirmed (absence of evidence).
- Elgato publishes the Stream Deck + HID protocol (VID 0x0FD9, PID 0x0084, encoder press/rotate, touch tap/press/flick, image upload).
  https://docs.elgato.com/streamdeck/hid/stream-deck-plus (undated): confirmed.
- Elgato's HID docs are for advanced use at the user's own risk.
  https://docs.elgato.com/streamdeck/hid/intro (undated): confirmed.
- Community Linux apps were built from a reverse-engineered protocol.
  https://cyberpanel.net/blog/stream-deck-linux (undated): unconfirmed (secondary).
- OpenDeck handles + dial rotate and press.
  https://github.com/nekename/OpenDeck (src-tauri/src/elgato.rs) (2026-10-20): confirmed (source).
- OpenDeck renders to the touch strip (v2.13.0) and forwards taps and long-presses, not swipes.
  https://github.com/nekename/OpenDeck/releases (2026-06-26 to 2026-10-11): confirmed.
- OpenDeck's latest release is v2.14.2, with 12 releases since 2026-02-14.
  https://api.github.com/repos/nekename/OpenDeck/releases (2026-10-21): confirmed.
- OpenDeck runs Elgato SDK plugins, needing Wine for Windows-only ones and Node.js for Node ones.
  https://github.com/nekename/OpenDeck (2026-10-21): confirmed.
- StreamController lists Stream Deck Plus and Plus XL as supported.
  https://github.com/StreamController/StreamController (2026-09-21): confirmed.
- StreamController handles dial turn/push and strip tap, long-press and drag, with a dedicated Plus UI.
  https://github.com/StreamController/StreamController (src/windows/mainWindow/DeckPlus/) (2026-09-21): confirmed (source).
- StreamController's newest release is 1.5.0-beta.15 (2026-07-09), beta.16 pre-release (2026-08-16); all 1.5.x are betas.
  https://api.github.com/repos/StreamController/StreamController/releases (2026-08-16): confirmed.
- StreamController uses its own plugin system, not Elgato's.
  https://github.com/nekename/OpenDeck (2026-10-21): unconfirmed (only OpenDeck's README says so).
- Boatswain handles + keys, touch strip (short/long/swipe) and dials.
  https://gitlab.gnome.org/World/boatswain (lib/devices/elgato/elgato-stream-deck-plus.c) (2026-10-14): confirmed (source).
- Boatswain's latest tag is 6.0; 6.1 is untagged.
  https://gitlab.gnome.org/api/v4/projects/World%2Fboatswain/repository/tags (2026-04-11): confirmed.
- streamdeck-linux-gui (v4.1.5) lists Original, MK2, Mini and XL only, with no + dial or strip code.
  https://github.com/streamdeck-linux-gui/streamdeck-linux-gui (2026-10-14): confirmed.
- streamdeck-ui (timothycrosley) is stale since 2024-04-28 with no + support.
  https://github.com/timothycrosley/streamdeck-ui (2024-04-28): confirmed.
- deckmaster is stale (v0.9.0, 2023) with no + support.
  https://github.com/muesli/deckmaster (2023-03-12): confirmed.
- A user reports OpenDeck working with + encoders on KDE and PipeWire.
  https://discuss.cachyos.org/t/an-ai-summary-of-how-i-got-my-stream-decks-working-well-in-catchyos/21769 (undated): unconfirmed (secondary).
- `sjourdois/opendeck-pipewire` gives dials default output/input, named device and named app volume; press mutes; strip shows a level bar; needs OpenDeck 2.13.1+.
  https://github.com/sjourdois/opendeck-pipewire (2026-10-18): confirmed.
- `mdvictor/opendeck-volume-controller` gives per-app dial volume via PulseAudio with a strip bar, no default sink.
  https://github.com/mdvictor/opendeck-volume-controller (2026-10-03): confirmed.
- `jeremyfry/linux-streamdeck-volume-knobs` controls system or one app via `wpctl`, no level bar, low activity.
  https://github.com/jeremyfry/linux-streamdeck-volume-knobs (2026-01-15): confirmed.
- StreamController's VolumeMixer has a + Dial action (turn, press mutes, name and percentage shown), auto-assigning apps in playing order, so no pinning.
  https://github.com/StreamController/VolumeMixer (2026-08-14): confirmed.
- No plug-and-play way to pin an app to a StreamController dial.
  https://github.com/StreamController/StreamController/discussions/157 (2024-07-07): superseded by the VolumeMixer Dial action (2024-10-20) for auto-assign; pinning still needs scripts.
- `com.sfgrimes.pipewire-audio` covers master, mic, per-app and device selection with dials.
  https://marketplace.tacto.live/plugin/com.sfgrimes.pipewire-audio (undated): unconfirmed (no source repo found).
- That plugin's `{{value}}` touch-strip bug was fixed.
  https://github.com/nekename/OpenDeck/issues/371 (2026-07-02): confirmed (closed after plugin update).
- DeckWeaver controls PipeWeaver virtual devices with dials and meters.
  https://github.com/designgears/DeckWeaver (undated): confirmed (README).
- nixpkgs `streamcontroller` is 1.5.0-beta.14.
  https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/streamcontroller/package.nix (2026-05-21): superseded by upstream 1.5.0-beta.15 (2026-07-09).
- nixpkgs `streamdeck-ui` is 4.1.4.
  https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/st/streamdeck-ui/package.nix (undated): superseded by upstream v4.1.5 (2026-10-14).
- nixpkgs `boatswain` is 5.0.
  https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/bo/boatswain/package.nix (2025-03-28): contradicted by the Boatswain tags API: 6.0 tagged 2026-04-11, so nixpkgs lags.
- OpenDeck is not in nixpkgs; the request was closed as not planned.
  https://github.com/NixOS/nixpkgs/issues/356016 (2025-09-02): confirmed.
- `programs.streamcontroller` installs the package and its udev rules.
  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/streamcontroller.nix (2026-10-21): confirmed.
- `programs.streamdeck-ui` installs the package, autostarts it and adds its udev rules.
  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/programs/streamdeck-ui.nix (2026-10-21): confirmed.
- StreamController's udev rules cover 0fd9:0084 (Stream Deck Plus).
  https://github.com/StreamController/StreamController/blob/main/udev.rules (2026-09-21): confirmed.
- OpenDeck needs `40-streamdeck.rules` installed by hand outside .deb/.rpm.
  https://github.com/nekename/OpenDeck (2026-10-21): confirmed, but not needed on the desktop.
- systemd's `70-uaccess.rules` grants uaccess to hidraw and usb devices tagged
  `ID_AV_PRODUCTION_CONTROLLER`, and its hwdb tags the Stream Deck +, so the logged-in user
  gets it without any app's rules.
  Checked on the desktop, `/dev/hidraw13` ACL and `udevadm info` (2026-10-22): confirmed.
- OpenDeck's active-window crate `active-win-pos-rs` 0.10.1 only supports KDE on Wayland.
  https://github.com/dimusic/active-win-pos-rs/blob/0.10.1/README.md (2026-03-13): superseded by v0.11.0 (2026-05-26), which adds Hyprland, but OpenDeck v2.14.2 still locks 0.10.1.
- StreamController's auto page switching reads Hyprland natively via `hyprctl` and socket2.
  https://github.com/StreamController/StreamController/blob/main/src/backend/WindowGrabber/Integrations/Hyprland.py (2026-09-21): confirmed.
- StreamController locks the deck on a Hyprland screen lock.
  https://github.com/StreamController/StreamController/blob/main/src/backend/Wayland/Wayland.py (2026-09-21): confirmed.
- OpenDeck sends keystrokes with enigo (wayland, libei, x11rb features).
  https://github.com/nekename/OpenDeck/blob/main/plugins/com.amansprojects.starterpack.sdPlugin/Cargo.toml (2026-10-20): confirmed.
- streamdeck-ui sends keys via uinput; `hardware.uinput` needs the user added to the `uinput` group.
  https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/hardware/uinput.nix (2026-10-15): confirmed.
- Boatswain needs udev 250+ and doesn't list window-based page switching.
  https://gitlab.gnome.org/World/boatswain (2025-03-28): confirmed.

## Gaps

- Nothing was run on the hardware or on Hyprland: every support verdict rests on source code and READMEs.
- How StreamController sends keystrokes on Wayland: its hotkey plugin lives outside the main repo and wasn't checked.
- Whether StreamController has a plugin for default-sink volume on a dial (its AudioControl plugin wasn't found).
- How OpenDeck finds Wine and Node on NixOS.
- Whether an OpenDeck PR bumps `active-win-pos-rs` to 0.11 for Hyprland.
- nixpkgs was read from `master`, not the `nixos-unstable` channel.
