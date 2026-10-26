# The desktop

The NixOS desktop is a host in the hive like the LXCs and the mini, but
merging never deploys it. The PR build check builds it on the builder,
which fills the cache, and Shane switches it on the desktop when she's
ready. [docs/workstation](../workstation/README.md) covers what it shares
with the Macs.

Monitoring is off, so a powered-off desktop doesn't page anyone. Its logs
still reach Loki.

The hive's Tailscale is off too, because it joins with an agenix OAuth
secret and the desktop's host key isn't one of its recipients. The desktop
enables Tailscale itself, with MagicDNS through resolved. Without resolved,
tailscaled overwrites `/etc/resolv.conf` and fights NetworkManager.
`FallbackDNS` is empty so resolved never goes round Blocky to a public
resolver, and its mDNS is off because Avahi already has port 5353.

## Switching

Wait for the PR's `build (desktop)` check to go green first, so the switch
downloads what the builder made instead of compiling it here. Then run
`nrs`, which switches to the forge's `main`. To switch to unmerged work,
`git add` any new files in the caboodle checkout and run either of:

```sh
colmena apply-local --sudo
nrs --local
```

- Colmena can't deploy the desktop over SSH. Root has no keys there and
  sshd refuses root logins.
- Home Manager is part of the system switch. `home-manager switch` or
  running a generation's `activate` by hand fires its activation hooks
  outside a switch, so only do that when Shane asks for exactly that.
- Switching is passwordless. If it prompts for a password, the sudo command
  it ran didn't match a rule in `modules/workstation/nixos/user.nix`, so
  look at that rather than assuming Shane has to type it.
- A switch doesn't restart PipeWire, WirePlumber or pipewire-pulse, which
  run as Shane's user services, so audio config changes wait for
  `systemctl --user restart pipewire pipewire-pulse wireplumber`. Audio
  drops for a second while they restart.

## Game streaming

Sunshine streams the desktop to Moonlight on the Macs and the Deck, over
the LAN or Tailscale. Its admin UI only answers on the desktop itself, at
`https://localhost:47990`. Give it a unique username and password, since
whoever controls it can pair new clients. Moonlight shows a PIN, which goes
on the UI's PIN page.

Moonlight lists two apps. Desktop streams DP-2 as it is. Steam runs
`sunshine-stream start`, which makes a headless Hyprland output called
`STREAM` at the client's resolution and frame rate, moves Steam's workspace
onto it, turns the physical monitors off and opens Big Picture fullscreen.
Games then render at the client's size rather than 4K. Quitting the app in
Moonlight runs `sunshine-stream stop`, which puts it all back; only
disconnecting leaves the game running to come back to. If the monitors stay
dark anyway, Super + Shift + M runs the stop from the desk.

- Set Moonlight's resolution to Native on each client. Its default is
  1280x720, which letterboxes the Deck's 1280x800.
- A game that saved exclusive fullscreen at 4K draws a 4K frame into the
  smaller output and shows its top-left corner. Borderless fills whatever
  output it's on, so use that. Cap the frame rate too: the headless output
  has no vsync, so an uncapped game burns CPU on frames the stream drops.
- Hyprland allows one fullscreen window per workspace, so a game knocks Big
  Picture out of fullscreen and it stays tiled after the game quits.
  `exit_window_retains_fullscreen` hands fullscreen back to the next focused
  window. The stream turns it on and `stop` restores the config's value,
  since at the desk it would fullscreen whatever sits behind a closed video.
- `output_name` matches Hyprland's output names. When none matches, Sunshine
  quietly streams the first output, which is how Desktop gets DP-2.
- Hyprland's config is Lua, so runtime changes go through `hyprctl eval`.
  `hyprctl keyword`, which most shared Sunshine scripts use, does nothing.
- If encoding breaks after a Mesa or kernel update,
  `, vainfo --display drm --device /dev/dri/renderD128` should list
  `VAEntrypointEncSlice` for H.264, HEVC and AV1. `renderD128` has to stay
  the discrete GPU; the iGPU is `renderD129`.
- Away from home, Tailscale needs a direct path or the stream goes through
  a DERP relay, which is too slow for it: Moonlight goes blocky and warns
  about a slow connection, and `tailscale status` shows `relay`. A phone
  hotspot's carrier NAT can't hole-punch, so the gateway forwards
  tailscaled's UDP port to the desktop. Only the desktop gets one; other
  hosts that need a direct path get their own port.
- HDR needs KMS capture and `cap_sys_admin`, which this setup avoids, so
  it's unproven here.

## GPU crash dumps

The desktop saves AMDGPU crash dumps by itself. Each one gets a directory
under `/var/lib/amdgpu-crash-dumps/`, and a `.partial` dump means the
capture didn't finish. Nothing is uploaded, but review them before sharing.

Proton logs aren't collected. Set the game's Steam launch option to
`PROTON_LOG=1 %command%` to get one.

The collector only runs when a dump appears, so an inactive template is
normal. To check on it:

```sh
systemctl cat amdgpu-dump@.service
journalctl -b -u 'amdgpu-dump@*' --no-pager
ls -l /var/lib/amdgpu-crash-dumps/
```

The kernel's dump expires after about five minutes and doesn't survive a
reboot, and a hard lockup can stop the capture altogether. The tests use
fixtures, so the first real crash is the only end-to-end test.

## Lighting

The OpenRGB server holds the RAM, motherboard, GPU and monitor lights, and
Home Assistant drives them through its OpenRGB integration, so they can join
the desk scenes. Only the Home Assistant host can reach the server's port,
because the SDK has no authentication. The integration lives in Home
Assistant's UI: add OpenRGB with the desktop's LAN address and port 6742.

Home Assistant owns when the lights are on. A reboot or suspend puts the
RAM back on its rainbow, and Home Assistant only guesses the lights' state,
so an automation that sets them when they come back from unavailable is
what catches it.

- The Kingston RAM has no Off mode, so off is Direct and black.
- The ASRock board ignores colours but obeys off.
- The monitor's logo is dim, so check it with the room dark. It only
  listens with Aura Sync on in its own menu. Powering the monitor off, or
  the KVM switching away, re-enumerates its USB hub and gives the logo a
  new hidraw node, so a udev rule restarts the server when it comes back.
  Detection only reads the RAM, GPU and board, so the restart leaves them
  as they were.
- The cooler's white light isn't on any controller, so nothing here
  switches it.
- The OpenRGB GUI runs as Shane and talks to the same server, so changes
  there don't fight Home Assistant's.

## Stream Deck

OpenDeck drives the Stream Deck +, and its dials turn the volume of
PipeWire channels: Game, Music, Browser and Chat are virtual outputs that
play into the default device. There's no System channel, because System is
the default device itself, so anything not sent to a channel lands there.
Shane moves an app onto a channel from Noctalia's mixer, and WirePlumber
remembers that app's channel from then on.

- Never make a channel the default output. Each channel plays into the
  default, so a channel there would play into itself.
- Chrome plays every tab and PWA through one stream, so a YouTube PWA and
  a tab can't go to different channels.
- OpenDeck owns `~/.config/opendeck`: profiles, plugins and their
  layouts. Its backup button zips all of it. The touch strip's background
  and dividers are edits to the PipeWire plugin's `layouts/volume.json`,
  so a plugin update resets them.
- systemd's `70-uaccess.rules` gives the deck to the logged-in user, so it
  needs no udev rule of its own.

## Emulation

The emulators, and where their games and saves live, are shared with the
Deck; see [docs/workstation](../workstation/README.md#emulation). Here,
`~/Emulation` is the NAS's `games` share.

## Gotchas

- nh's weekly clean deletes old generations, so the boot menu can only roll
  back as far as the last clean.
- NixOS modules get `palette` and `typography` from
  `modules/workstation/nixos`, and `shell` from the host file, as module
  arguments. A module can take them as function arguments but can't use
  them in `imports`, since module arguments aren't known yet when imports
  are resolved.
- Noctalia keeps its own nixpkgs pin, so it matches its Cachix cache
  instead of building here, and tracks upstream's `cachix` branch, which
  trails main to the newest commit their CI has cached. Hyprland comes from
  our nixpkgs, so the NixOS cache has it.
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
- After a boot or replug, the Wave:3's first mute press reaches the
  computer and PipeWire mutes `Elgato Wave 3 Mono`, but the unmute press
  doesn't, so the mic stays muted while its light shows live. Unmuting
  that source in the mixer fixes it, and from then on the button mutes and
  unmutes inside the mic until the next replug. Unmuting from the computer
  before the first press doesn't help, since the mic only hands the button
  over once the computer answers its mute. Replugging resets the mic, but
  OBS doesn't reconnect a capture source whose device went away, so OBS
  needs a restart after it.
