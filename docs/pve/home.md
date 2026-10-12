# Home

NixOS LXC on PVE running Home Assistant at `https://home.shaneplunkett.com`.
The container is `module "home"` in `terraform/pve-home.tf`, and the service is
`modules/services/home-assistant`. The plan for moving the apartment onto it is
in [the research notes](../research/home-assistant.md).

## Why a container image

Home Assistant runs from the official image under podman, not the nixpkgs
module. The nixpkgs build has no pip, so every new integration would need a
PR before it could be added, and HACS can't work at all. Most of Home
Assistant's config lives in its UI anyway. Renovate bumps the image tag.

It uses host networking, because discovery and HomeKit Controller pairing
need mDNS.

## First setup

Home Assistant blocks requests from a reverse proxy until it's told to trust
one, so the first visit has to skip the ingress:

1. Open the host's LAN address on port 8123 and create the owner account.
2. Under Settings, System, Network, turn on "Trust X-Forwarded-For" and add
   the ingress host's address to "Trusted proxies".
3. From then on, use `https://home.shaneplunkett.com`.

These settings live in the UI, not `configuration.yaml`. A YAML
`http:` block only gets imported once, and then a repair asks you to delete it.

## HACS

HACS isn't in Nix. It was installed once into the config volume with its
official script, and it updates itself from the UI after that:

```sh
ssh root@home 'podman exec homeassistant bash -c "wget -O - https://get.hacs.xyz | bash -"'
ssh root@home systemctl restart podman-homeassistant
```

Then add the HACS integration in the UI, which links it to GitHub with a
device code. Anything installed through HACS lives in `custom_components`,
so the backup covers it.

## Custom cards

Dashboard cards written here live next to the module, and each is mounted
read-only into the config volume's `www` folder, which Home Assistant serves
at `/local/`. A card only shows up once it's registered as a resource:
Settings, Dashboards, the menu, Resources, then add `/local/<file>.js` as a
JavaScript module. That menu only appears with Advanced mode on in your
profile.

- **Browsers cache `/local/` hard.** After a card changes, add or bump a
  `?v=` on its resource URL, or the old card keeps loading.
- **The Dyson card** needs `ha-dyson` from HACS. If its dial turns the
  opposite way to the Dyson app, set `reverse: true` on the card. It only
  shows sleep timers it started itself, because `ha-dyson` doesn't report the
  fan's timer.

## Signing in

Home Assistant has no OIDC login of its own, so hass-oidc-auth (`auth_oidc`,
from HACS) adds a Pocket ID button. It isn't behind the oauth2-proxy gate,
because the iPhone app can't get through a proxy login.

- The Pocket ID client is `home`, with the callback
  `https://home.shaneplunkett.com/auth/oidc/callback`. Its secret is
  `home-oidc-client-secret` in Bitwarden.
- The client is configured in Home Assistant's UI, under Devices & services,
  so the secret lives in Home Assistant's own storage rather than agenix.
- Both the admin and user roles are `home_admins`, so nobody outside that group
  gets in at all.
- Automatic user linking was on only long enough to link the passkey to the
  existing owner account. Leave it off: it links by username alone.
- The iPhone app can't open the passkey page itself, so it shows a code. Start
  a fresh SSO login in a private window or in Safari, and after the passkey
  there's a screen to enter the code. Being signed in already doesn't show it.
  The app picks it up by itself.

**If Pocket ID is down,** the owner's password login still works. Pick the
other login method on the welcome screen. The password is in Bitwarden.
Sessions already signed in keep working, because Pocket ID is only used at
login.

## Reaching the IoT network

The smart home devices are on the IoT VLAN. One UniFi zone policy, "Home
Assistant to IoT", lets the home host into the IoT zone, with return traffic
allowed. IoT devices still can't start a connection to anything on the LAN.
Every IoT device has a fixed IP, so Home Assistant can find it even when mDNS
gets flaky.

## Vex's access

Vex has its own admin user, `Vex`, and a long-lived token in Bitwarden as
`home-assistant-vex-token`. The logbook shows what Vex did, and disabling the
user cuts it off without touching Shane's login.

Some changes are only on the websocket API, not REST: enabling an entity,
setting a device's area or name, and listing discovered devices.

## After a power cut

The "Turn things off after a power cut" automation turns off any light that
comes back on by itself. It leaves the Play bars alone, and only switches off
plugs listed in its `plugs` variable.

- It only acts in the first 20 minutes after pve boots. Home Assistant
  restarting, or a device dropping off Wi-Fi and coming back, isn't a power
  cut, and it would otherwise turn off a 3D printer mid-print.
- It reads pve's boot time from System Monitor's `sensor.system_monitor_uptime`.
  Inside podman, `/proc/uptime` is the Proxmox host's, not the LXC's, which is
  exactly the signal a power cut leaves. System Monitor turns that sensor off
  by default, so it has to be enabled.
- Lights without a power-on setting still flash on for a moment before it
  catches them.

## Scenes

Starlight is a Home Assistant scene copied from the Hue bridge's own scene
definition, so it survives the Play bars leaving the bridge. Hue's version
lives on the bridge as `scene.*_starlight`. Ours is `scene.starlight`.

## Backups

The recorder database is copied with SQLite's `.backup` to `backup.db` before
restic runs, and the live file is excluded. To restore, put `backup.db` back as
`home-assistant_v2.db` with `podman-homeassistant` stopped. Home Assistant's own
`backups` folder is excluded, because restic already covers everything in it.

## Zigbee

Zigbee2MQTT and Mosquitto run natively on the host, from nixpkgs. Zigbee2MQTT
reaches the SLZB-06P7 coordinator over TCP on the IoT VLAN, and hands devices
to Home Assistant through Mosquitto, which only listens on localhost. Its
frontend is the `zigbee` route, behind the oauth2-proxy gate.

- **The network is on channel 15.** The Wi-Fi's 2.4 GHz is on channel 11,
  which crowds Zigbee 20 to 25. The Hue bridge sat on 25, and its far lights
  kept dropping off.
- **Never lose or change the network key.** It's `zigbee2mqtt-network-key`
  in Bitwarden and `zigbee2mqtt-secret` in agenix. Zigbee2MQTT reads it from
  `secret.yaml`, a symlink to the agenix secret, so it stays out of the Nix
  store. A new key means re-pairing every device. The PAN IDs are in Nix and
  matter just as much.
- **Nix rewrites `configuration.yaml` on every start,** so settings changed in
  the frontend don't survive a restart. Put them in Nix. Devices and groups
  live in `devices.yaml` and `groups.yaml`, which Nix leaves alone.
- **`version` is pinned** to the current config version, so Zigbee2MQTT
  doesn't try to migrate the file Nix writes.
- The backup covers `/var/lib/zigbee2mqtt`, including the coordinator backup
  Zigbee2MQTT keeps, which is what moves the network to a new coordinator.

## Thread

The Eve Aqua is a HomeKit-over-Thread device, paired to Home Assistant through
Apple's border routers (the HomePod and the Apple TV). Home Assistant reaches
the Thread network through the route those routers advertise.

- **The home host has to accept IPv6 router adverts.** Proxmox writes
  `IPv6AcceptRA = false` into the container's `eth0.network`, so the module
  adds a drop-in that turns it back on. Without the route, pairing fails with
  `NetworkError`.
- **Every Apple border router has to be on the main LAN.** When the Apple TV
  sat on the IoT VLAN, the Aqua's replies left through it and were dropped at
  the firewall, so pairing timed out. The same split is why the Apple TV kept
  reporting network issues.
- The Aqua is a sleepy battery device. Press its button to wake it before
  pairing.

## Moving devices over

- **Hue lights:** unplug the Hue bridge before resetting them. While it's
  running, half-reset lights drift back to it. With it off, a power-cycle reset
  (off 2 seconds, on 8, five times) or the Hue dimmer (power + Hue, about 10
  seconds) gets them into Zigbee2MQTT within seconds. Zigbee2MQTT's
  serial-number reset wipes every serial listed, including lights that have
  already joined.
- **HomeKit devices** (Meross, Sensibo, the Aqua) come over with HomeKit
  Controller: remove them from Apple Home, then pair with their code. Sensibo
  only shares on/off, mode and temperature that way, so the Sensibo cloud
  integration sits beside it for the flap and fan. The local one is hidden.
- **The balcony Shelly** runs the community shelly-homekit firmware, so it pairs
  through HomeKit Controller too. Its RPC `Shelly.SetConfig` reboots it without
  saving, so change settings in its web page, which is only reachable from the
  home host (`ssh -L 8115:<shelly>:80 root@home`). It's set to edge input and
  off after a power cut, and shows up as a light through Switch as X.

## The IoT leg

The home container has a second interface, `eth1`, tagged onto the IoT VLAN,
with a static address and no gateway, so `eth0` keeps the default route. It's
there for Matter, which talks IPv6 link-local and can't cross the router the
way HomeKit and Hue do. pve's `vmbr0` is VLAN-aware for it, a change made by
hand in `/etc/network/interfaces` (`bridge-vlan-aware yes`, `bridge-vids
2-4094`). Its switch port already allows every VLAN.

Traffic to the IoT VLAN now goes straight out of `eth1` rather than through the
router, so the "Home Assistant to IoT" firewall policy only matters if `eth1`
goes away. IP forwarding is off, so the host doesn't route between the two.

## Matter

The matter.js server, Home Assistant's current Matter stack, runs natively from
nixpkgs and listens for Home Assistant on localhost. Its storage holds the Matter
fabric's keys, so it's backed up. Losing it means re-sharing every Matter device.

Matter devices already in Apple Home join by sharing: in the Home app, open the
device's settings, turn on pairing mode, and give Home Assistant the code it
shows. The device stays in Apple Home as well.

- **Apple Home can only open pairing mode while its hub reaches the device.**
  The Apple TV lives on the main LAN for Thread, so Matter devices on the IoT
  VLAN show "No Response" there. To share one, move the Apple TV's switch port
  and DHCP reservation to IoT, restart it, share the device, then move it back
  and restart it again. Once Home Assistant has a device, Apple Home losing it
  doesn't matter.
- **Home Assistant's network adapters include `eth1`** (Settings, System,
  Network), so discovery sees the IoT VLAN.

### LIFX switches

The Matter update hides in the switch's advanced settings in the LIFX app, and
only shows while the app can reach the switch through LIFX's cloud. If the app
says it's disconnected, join the phone to the IoT Wi-Fi to reconnect it. The
update ends with a Matter code, and the switch joins Home Assistant with it
directly.

- **Each button is welded to its relay** until its actions are cleared in the
  LIFX app. After that, a press only reaches Home Assistant as an event, which
  automations act on. The bathroom lights button works this way, because its
  relay feeds the WiZ bulb and the basin switch, which are wired in series.
  That relay powers on after a power cut so both stay reachable.
- **Every press arrives as three events** within a millisecond. Automations on
  the buttons run in `single` mode and end with a short delay, so they act
  once.
- Buttons that still drive their relay report presses too.

## Music Assistant

Music Assistant runs next to Home Assistant on this host, from its official
image under podman with host networking, for the same reasons as Home
Assistant. It's `modules/services/music-assistant`, at
`https://music.shaneplunkett.com`. It pulls music from the streaming
services and plays it on the speakers, and Home Assistant drives it through
the Music Assistant integration.

It has no OIDC login, so it sits behind the oauth2-proxy gate. Its own login
has been mandatory since 2.7 and can't be turned off, so it asks for its
admin password after the passkey. That account is in Bitwarden as
`music-assistant-admin`.

### First setup

1. Open `https://music.shaneplunkett.com` and create the admin account.
2. In Home Assistant, add the Music Assistant integration with
   `http://localhost:8095`, then press its Authenticate button and sign in
   as the admin.

### Gotchas

- **Leave the stream server's published IP on auto.** Music Assistant hands
  it to AirPlay speakers as its clock's address, and a speaker ignores clock
  packets from any other address. This host is on two networks, so pinning
  the address to one of them silences every AirPlay speaker on the other.
  That's how the bathroom HomePod went quiet. On auto, Music Assistant uses
  whichever address faces each speaker.
- **The Bose plays over AirPlay 2, and needs to stay that way.** AirPlay
  pushes audio to the speaker. Google Cast has the speaker pull it from the
  published address instead, and on auto that's the main LAN, which the IoT
  VLAN can't reach. If the Bose ever shows as playing over Cast and stays
  silent, that's why.
- **AirPlay 2 keeps time over PTP,** on UDP 319 and 320, so both are open on
  the home host.
- **The Bose soundbar's Google Cast is off** until it's turned on in the
  Bose app, and Home Assistant's Cast integration needs it. It needs nothing
  from Google beyond accepting their terms there.

### YouTube Music

YouTube has no API for this, so the source logs in with a browser cookie and
needs a PO token server to vouch that its requests come from a real browser.
The PO token server runs next to Music Assistant and only listens locally,
which is the source's default address. Music Assistant installs the newest
PO token plugin when it starts, so the server tracks the newest release too,
whatever version Music Assistant's docs name.

`tools/music-assistant/youtube-cookie.py` gets the cookie. It opens Chrome on
a throwaway profile to sign in to YouTube Music, takes the cookie when the
window closes, and deletes the profile. When the source doesn't exist yet, it
puts the cookie on the clipboard to paste into Music Assistant's add-source
form. After that it updates the source in place, so it's the fix whenever the
source starts failing with a 401 or "Unable to fetch PO Token".

- **The profile is thrown away on purpose.** Google swaps the cookies in any
  browser that keeps using YouTube, which kills the copy Music Assistant
  holds. With the profile gone, nothing is left to swap them.
