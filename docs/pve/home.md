# Home

NixOS LXC on PVE running Home Assistant, with Zigbee2MQTT, Matter and Music
Assistant beside it. The container is in `terraform/pve-home.tf` and the
services are imported in `hosts/home.nix`.

## Why a container image

Home Assistant runs from the official image, not the nixpkgs module. The
nixpkgs build has no pip, so every new integration would need a PR first,
and HACS can't work at all. Most of its config lives in the UI anyway.

## First setup

Home Assistant blocks a reverse proxy until it's told to trust one, so the
first visit skips the ingress:

1. Open the host's LAN address on port 8123 and create the owner account.
2. Under Settings, System, Network, turn on "Trust X-Forwarded-For" and add
   the ingress host's address to "Trusted proxies".
3. From then on, use `https://home.shaneplunkett.com`.

Set these in the UI. A YAML `http:` block only gets imported once, and then
a repair asks you to delete it.

## HACS

HACS isn't in Nix. It was installed once into the config volume, and
updates itself from the UI after that:

```sh
ssh root@home 'podman exec homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"'
ssh root@home systemctl restart podman-homeassistant
```

Then add the HACS integration in the UI, which links it to GitHub with a
device code.

## Custom cards

Cards written here are served at `/local/`. A card only shows up once it's a
resource: Settings, Dashboards, the menu, Resources, then add
`/local/<file>.js` as a JavaScript module. That menu needs Advanced mode on
in your profile.

- **Browsers cache `/local/` hard.** After a card changes, bump a `?v=` on
  its resource URL.
- **The Dyson card** needs `ha-dyson` from HACS. If its dial turns the
  opposite way to the Dyson app, set `reverse: true`. It only shows sleep
  timers it started itself, because `ha-dyson` doesn't report the fan's.

## Signing in

hass-oidc-auth (`auth_oidc`, from HACS) adds a Pocket ID button. It isn't
behind the oauth2-proxy gate, because the iPhone app can't get through a
proxy login. Its client is set up in Home Assistant's UI, so the secret
lives there, not in agenix.

- Both the admin and user roles are `home_admins`, so nobody outside that
  group gets in.
- Leave automatic user linking off. It links by username alone.
- The iPhone app can't open the passkey page, so it shows a code. Start a
  fresh SSO login in a private window or Safari, and after the passkey
  there's a screen to enter it. Being signed in already skips that screen.

**If Pocket ID is down,** pick the other login method on the welcome screen
and use the owner's password from Bitwarden. Existing sessions keep working.

## Vex's access

Vex has its own admin user, with a long-lived token in Bitwarden as
`home-assistant-vex-token`. Disabling the user cuts Vex off without touching
Shane's login.

Some changes are only on the websocket API, not REST: enabling an entity,
setting a device's area or name, and listing discovered devices.

## After a power cut

The "Turn things off after a power cut" automation turns off lights that
come back on by themselves, and the plugs in its `plugs` variable.

- It only acts in the first 20 minutes after pve boots, so a Home Assistant
  restart or a device rejoining Wi-Fi can't turn off a 3D printer mid-print.
- It reads the boot time from System Monitor's
  `sensor.system_monitor_uptime`. Inside podman, `/proc/uptime` is the
  Proxmox host's, which is exactly what a power cut resets. System Monitor
  ships that sensor disabled, so it has to be turned on.

## Scenes

Starlight is copied from the Hue bridge's scene so it outlives the bridge.
Ours is `scene.starlight`, and the bridge's own is `scene.*_starlight`.

## Backups

To restore the recorder database, stop `podman-homeassistant` and put
`backup.db` back as `home-assistant_v2.db`.

## The IoT network

Every IoT device has a fixed IP, so Home Assistant finds it when mDNS gets
flaky.

The container's second leg, `eth1`, is on the IoT VLAN for Matter, which
talks IPv6 link-local and can't cross the router the way HomeKit and Hue do.
With it, the "Home Assistant to IoT" firewall policy only matters if `eth1`
goes away. It needs pve's `vmbr0` to be VLAN-aware, a change made by hand
in `/etc/network/interfaces`:

```
bridge-vlan-aware yes
bridge-vids 2-4094
```

## Zigbee

- **The channel stays clear of the Wi-Fi,** whose 2.4 GHz crowds Zigbee 20
  to 25. The Hue bridge sat on 25, and its far lights kept dropping off.
- **Never lose or change the network key** (`zigbee2mqtt-network-key` in
  Bitwarden) or the PAN IDs. Either means re-pairing every device.
- **Settings changed in the frontend don't survive a restart,** because Nix
  rewrites `configuration.yaml`. Put them in Nix. Devices and groups live in
  files Nix leaves alone.
- The coordinator backup Zigbee2MQTT keeps is what moves the network to a
  new coordinator.

## Thread

The Eve Aqua is HomeKit over Thread, reached through the route Apple's
border routers (the HomePod and the Apple TV) advertise.

- **The host has to accept IPv6 router adverts.** Proxmox turns
  `IPv6AcceptRA` off in the container's `eth0.network`, so the module turns
  it back on with a drop-in. Without the route, pairing fails with
  `NetworkError`.
- **Every Apple border router has to be on the main LAN.** When the Apple TV
  sat on the IoT VLAN, the Aqua's replies left through it and were dropped at
  the firewall, so pairing timed out.
- The Aqua is a sleepy battery device. Press its button before pairing.

## Pairing devices

- **Hue lights:** unplug the Hue bridge first, or half-reset lights drift
  back to it. Then a power-cycle reset (off 2 seconds, on 8, five times) or
  the Hue dimmer (power + Hue, about 10 seconds) works. Avoid Zigbee2MQTT's
  serial-number reset: it wipes every serial listed, including lights that
  already joined.
- **HomeKit devices** pair with HomeKit Controller once removed from Apple
  Home. Sensibo only shares on/off, mode and temperature that way, so the
  Sensibo cloud integration sits beside it for the flap and fan.
- **The balcony Shelly** runs shelly-homekit firmware, so it pairs the same
  way. Its RPC `Shelly.SetConfig` reboots it without saving, so change
  settings in its web page, which only the home host can reach:
  `ssh -L 8115:<shelly>:80 root@home`.

## Matter

The matter.js server's storage holds the fabric's keys. Losing it means
re-sharing every Matter device.

Devices already in Apple Home join by sharing: in the Home app, turn on
pairing mode in the device's settings and give Home Assistant the code. The
device stays in Apple Home too.

- **Apple Home can only open pairing mode while its hub reaches the
  device.** The Apple TV lives on the main LAN for Thread, so Matter devices
  on IoT show "No Response". To share one, move the Apple TV's switch port
  and DHCP reservation to IoT, restart it, share, then move it back and
  restart again.
- **Home Assistant's network adapters must include `eth1`** (Settings,
  System, Network), so discovery sees the IoT VLAN.

### LIFX switches

The Matter update hides in the switch's advanced settings in the LIFX app,
and only shows while the app reaches the switch through LIFX's cloud. If
it says it's disconnected, join the phone to the IoT Wi-Fi. The update ends
with a Matter code to pair with directly.

- **Each button is welded to its relay** until its actions are cleared in
  the LIFX app. After that, a press only reaches Home Assistant as an event.
  The bathroom button works this way, because its relay feeds the WiZ bulb
  and the basin switch in series, so that relay powers on after a power cut.
- **Every press arrives as three events** within a millisecond. Button
  automations run in `single` mode and end with a short delay, so they act
  once.

## Music Assistant

It has no OIDC login, so it sits behind the oauth2-proxy gate. Its own login
can't be turned off either, so it asks for its admin password,
`music-assistant-admin` in Bitwarden, after the passkey.

First setup:

1. Open `https://music.shaneplunkett.com` and create the admin account.
2. In Home Assistant, add the Music Assistant integration with
   `http://localhost:8095`, then press Authenticate and sign in as the admin.

- **Leave the stream server's published IP on auto.** AirPlay speakers only
  take clock packets from that address. The host is on two networks, so
  pinning it to one silences every AirPlay speaker on the other.
- **The Bose has to play over AirPlay 2, not Cast.** Cast has the speaker
  pull audio from the published address, which on auto is the main LAN, and
  the IoT VLAN can't reach it. A Bose playing over Cast stays silent.
- **The Bose's Google Cast is off** until it's turned on in the Bose app,
  and Home Assistant's Cast integration needs it.

The Music dashboard's card is added to HACS as a custom repository, since it
isn't in the default list, and its queue tab needs `droans/mass_queue`.

### YouTube Music

The source logs in with a browser cookie, and a PO token server vouches
that it's a real browser. Music Assistant installs the newest PO token
plugin when it starts, so the server tracks the newest release too,
whatever version Music Assistant's docs name.

When the source fails with a 401 or "Unable to fetch PO Token", run
`tools/music-assistant/youtube-cookie.py`. It throws its Chrome profile away
on purpose: Google swaps the cookies in any browser that keeps using
YouTube, which kills the copy Music Assistant holds.

## The living room

The Apple TV and the Bose soundbar share the TV, so the Apple TV is a
remote, not a speaker, and its Music Assistant player is disabled. The
YouTube script on the Home page puts the telly on in the order these need.

- **Pairing the Apple TV asks for three codes,** each shown on the TV.
  Someone has to be in front of it.
- **The Apple TV won't list its apps.** Launch them by bundle ID with
  `media_player.play_media` and `media_content_type: app`. YouTube is
  `com.google.ios.youtube`.
- **tvOS drops an app launch sent while it's waking.** Wait until it reports
  it's awake, then send the launch twice a few seconds apart.
- **The Bose has to be on its TV input before the TV wakes.** If it's still
  on AirPlay, eARC doesn't come up and the TV falls back to its own speakers
  without retrying.
- **The Bose integration** (`cavefire/Bose-Homeassistant`) wants a Bose
  account password, used once to fetch a key. An account made with Sign in
  with Apple has none until one's set through Bose's forgot password page.

## Later

- **SwitchBot lock,** through the built-in SwitchBot Bluetooth integration,
  which needs an ESPHome Bluetooth proxy near the door. pve's own Bluetooth
  can't do it: the kernel only allows Bluetooth sockets in the host's network
  namespace, and containers get their own. Decide which automations may
  unlock, not just lock.
- **Bedside Zigbee remote,** bound straight to the bedroom bulbs so it works
  with Home Assistant down.
- **The bathroom Shelly.** Check it still works, and whether it's on old
  HomeKit firmware like the balcony one was.
- **Bathroom fan on humidity,** with a cheap Zigbee sensor, since the
  HomePod's isn't reachable.
- **3D printer integration,** and **a Thread border router of our own** so
  Apple drops out entirely.
