# Moonlight from the NixOS desktop to a Mac

_Researched and locally preflighted 5 August 2026. Upstream and package
versions are a point-in-time snapshot._

## Verdict

**Yes: this is workable on Shane's current machines, including hardware H.264,
HEVC Main/Main10 and AV1 at both ends.** It is not merely compatible on paper. A
local preflight of the repo's pinned Sunshine `2026.516.143833` on the live
desktop successfully:

- found Hyprland's `zwlr_screencopy` interface and captured `DP-2`;
- selected the Radeon RX 7900 XTX at `/dev/dri/renderD128`;
- created VA-API H.264, HEVC, AV1, 10-bit HEVC and 10-bit AV1 encoders; and
- brought up the Sunshine web UI.

The Mac client is Shane's 14-inch MacBook Pro `Mac15,6`, with an M3 Pro, 36 GB
RAM and macOS 26.5.1. Apple documents hardware-accelerated H.264/HEVC and AV1
decode for that exact model family
([Apple specifications](https://support.apple.com/en-us/117736),
[Apple model identification](https://support.apple.com/en-us/108052)).

The sensible first target is **SDR 1080p60 or 1440p60 over the wired host LAN,
using wlroots capture and VA-API**. Move to 4K and/or AV1 only after the Mac's
decoder and network path pass Moonlight's performance-overlay test. Linux HDR
is a separate experiment because the pinned Sunshine documentation requires
KMS capture and calls Linux HDR support experimental
([upstream HDR notes](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/getting_started.md#L623-L654)).

The installed versions are also the current stable upstream releases:
Sunshine `2026.516.143833` and Moonlight PC `6.1.0`. The Sunshine release
contains a critical security update, so using this version rather than an older
tutorial pin matters
([Sunshine release](https://github.com/LizardByte/Sunshine/releases/tag/v2026.516.143833),
[pinned nixpkgs Sunshine recipe](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/pkgs/by-name/su/sunshine/package.nix#L97-L110),
[Moonlight release](https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.1.0),
[pinned nixpkgs Moonlight recipe](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/pkgs/by-name/mo/moonlight-qt/package.nix#L25-L35)).

## Why this desktop is a strong host

The live host is a Ryzen 7 7800X3D with a Sapphire Radeon RX 7900 XTX (Navi 31),
kernel `6.18.39`, `amdgpu`, Mesa `26.1.5`, Hyprland/Wayland and PipeWire. Its
main display is `DP-2` at 3840x2160@240 with a second rotated 1440p display on
`HDMI-A-1`; those names and modes are declared in
[`home/shane/modules/linux/hyprland.nix`](../../home/shane/modules/linux/hyprland.nix).
The repo already enables AMD graphics and 32-bit graphics support in
[`hosts/desktop/modules/hardware-custom.nix`](../../hosts/desktop/modules/hardware-custom.nix)
and selects `amdgpu` in
[`hosts/desktop/modules/services/default.nix`](../../hosts/desktop/modules/services/default.nix).

There are two AMD GPUs: the 7900 XTX is `/dev/dri/renderD128` at PCI
`0000:03:00.0`, while the Ryzen iGPU is `/dev/dri/renderD129`. Pinning the
adapter avoids Sunshine choosing the iGPU. Upstream documents `adapter_name`,
the `/dev/dri/renderD*` discovery process and the minimum H.264 encode profile
it expects
([adapter selection](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L877-L921)).

This matches Sunshine's official matrix: Linux supports AMD VA-API encoding,
wlroots capture, and the wlroots-to-VA-API combination
([encoding matrix](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/README.md#L89-L198),
[capture matrix](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/README.md#L200-L339)).
Its published 4K recommendation is a much older AMD encoder generation plus a
wired host and client, although upstream warns that the requirements table is a
work in progress
([requirements](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/README.md#L344-L445)).
The direct encoder test is therefore stronger evidence than the generic table.

## Recommended NixOS configuration

Start with this host configuration. It keeps the unneeded, very broad
`CAP_SYS_ADMIN` capability off, forces the already-proven Hyprland/VA-API path,
and pins both the discrete GPU and primary display:

```nix
{
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = false;

    # Simple LAN setup. This opens Sunshine's standard TCP/UDP ports in the
    # host firewall, but does not create router/NAT port forwards.
    openFirewall = true;

    settings = {
      capture = "wlr";
      encoder = "vaapi";
      adapter_name = "/dev/dri/renderD128";
      # Sunshine reported DP-2 as display ID 0 during the local preflight.
      output_name = 0;

      upnp = "disabled";
      origin_web_ui_allowed = "lan";
      lan_encryption_mode = 2;
      wan_encryption_mode = 2;
    };
  };

  # Required on this nixpkgs pin: services.sunshine enables the uinput
  # device/group but does not add the desktop user to it.
  users.users.shane.extraGroups = [ "uinput" ];
}
```

Why these choices:

- `wlr` explicitly means wlroots' `wlr-screencopy-unstable-v1`, including
  Hyprland, and does not require `CAP_SYS_ADMIN`. KMS does require that
  capability; X11 is the slowest and most CPU-heavy option
  ([capture settings](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L2066-L2124)).
  The local automatic-capture preflight first spent about 25 seconds waiting on
  unavailable XDG Portal interfaces before falling back successfully to
  wlroots, so pinning `wlr` also avoids that delay.
- `output_name` takes the detected display ID rather than the connector name
  on Linux. Sunshine's local startup log identified `DP-2` as monitor `0`
  ([output selection](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L923-L966)).
- `vaapi` is Sunshine's explicit AMD/Intel Linux encoder choice. Codec modes
  should stay at their defaults (`hevc_mode = 0`, `av1_mode = 0`), which
  advertise only capabilities the encoder probe actually finds
  ([encoder choices](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L2127-L2172),
  [HEVC/AV1 probing](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L1982-L2064)).
- Encryption mode `2` makes encryption mandatory and rejects unencrypted
  clients. Moonlight 6 supports full end-to-end stream encryption with
  Sunshine 0.22 or later; Sunshine warns encryption can cost performance on
  weak hosts/clients
  ([Moonlight 6 release](https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.0.0),
  [Sunshine encryption modes](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L1659-L1731)).
- `upnp = "disabled"` prevents Sunshine from asking the router to expose the
  service to the Internet. The web UI remains LAN-origin only
  ([network settings](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L1450-L1471),
  [web UI origin setting](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L1573-L1607)).

The pinned NixOS module installs Sunshine, enables Avahi discovery and
`hardware.uinput`, creates a graphical-session user service, and optionally
opens ports or wraps Sunshine with `cap_sys_admin`
([module implementation](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/nixos/modules/services/networking/sunshine.nix#L127-L196)).
There is one important hole: `hardware.uinput` only creates the group and makes
`/dev/uinput` mode `0660`, group `uinput`; it does not add Shane to the group
([uinput module](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/nixos/modules/hardware/uinput.nix#L7-L18)).
The local preflight's DS5 `Permission denied` warning directly confirmed the
effect. A logout/login or reboot is required after adding group membership.

Setting `services.sunshine.settings` makes those values declarative and not
editable in the web UI; the same is true of declarative `applications`
([option definitions](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/nixos/modules/services/networking/sunshine.nix#L58-L124)).
For a UI-first trial, enable the service and `uinput` membership first, omit
`settings`, confirm one stream, then add the proven settings above.

### Tighter LAN firewall alternative

`openFirewall = true` opens TCP `47984`, `47989`, `47990`, `48010` and UDP
`47998`, `47999`, `48000`, `48002`, `48010`
([NixOS port generation](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/nixos/modules/services/networking/sunshine.nix#L23-L25),
[firewall rules](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/nixos/modules/services/networking/sunshine.nix#L134-L148)).
Port `47990` is the admin UI, not a streaming port. Moonlight's Internet
forwarding list omits it
([official port list](https://github.com/moonlight-stream/moonlight-docs/blob/eee2f08df569b2309b4e0c79e0f987559fabe0a0/wiki/Setup-Guide.md#L209-L216)).

After the basic trial, a tighter configuration can leave
`services.sunshine.openFirewall = false`, allow only the streaming ports on
the wired `enp10s0` interface, and use the UI locally at
`https://localhost:47990`:

```nix
networking.firewall.interfaces.enp10s0 = {
  allowedTCPPorts = [ 47984 47989 48010 ];
  allowedUDPPorts = [ 47998 47999 48000 48002 48010 ];
};
```

The host already trusts `tailscale0` in
[`hosts/desktop/modules/networking.nix`](../../hosts/desktop/modules/networking.nix),
so no additional host firewall ports are needed for a Tailscale-only remote
path. Add the host manually in Moonlight when discovery does not cross that
overlay. Do not forward the web UI, and prefer the existing private overlay to
raw Internet port forwarding.

## Mac client

Moonlight PC 6.1.0 ships an official universal macOS DMG and requires **macOS
Big Sur 11 or later**
([release and download](https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.1.0),
[application minimum](https://github.com/moonlight-stream/moonlight-qt/blob/v6.1.0/app/Info.plist#L17-L21)).
That fits the repo's personal Mac target, which is `aarch64-darwin` in
[`flake.nix`](../../flake.nix). Moonlight advertises hardware-accelerated Mac
decoding plus H.264, HEVC and AV1 support; AV1 also requires a supported host
encoder
([Moonlight features](https://github.com/moonlight-stream/moonlight-qt/blob/v6.1.0/README.md#L1-L24)).

Moonlight is not currently installed on this Mac. The preferred declarative
path is available directly from the repo's nixpkgs pin. Add this to
`hosts/darwin/personal.nix` (and accept `pkgs` as a module argument):

```nix
environment.systemPackages = [ pkgs.moonlight-qt ];
```

Then build with `nh darwin build . -H Shanes-MacBook-Pro` and activate with
`nh darwin switch . -H Shanes-MacBook-Pro`. A dry run on the actual Mac
evaluated successfully, but Moonlight itself was not cached: it would build one
derivation locally after downloading roughly 457 MiB of dependencies (about
2.1 GiB unpacked). Nixpkgs installs `Moonlight.app` and a `moonlight` command
symlink
([Darwin install step](https://github.com/NixOS/nixpkgs/blob/61b7c44c4073f0b827768aff0049561b5110ea5a/pkgs/by-name/mo/moonlight-qt/package.nix#L73-L79)).
If that local source build is more purity than the job deserves, the official
universal DMG avoids it and is upstream's tested Mac artefact.

Use H.264 for the first connection. Try HEVC next for better quality per bit,
then AV1. The M3 Pro has hardware support for all three, though a live Moonlight
session still needs to establish which gives the best latency and image quality.
Moonlight 6.1 also records a known macOS issue:
Location Services background scans can cause periodic stutter on Wi-Fi
([v6.1 known issues](https://github.com/moonlight-stream/moonlight-qt/releases/tag/v6.1.0)).

For the network, upstream strongly recommends a wired host and either Ethernet
or strong 5 GHz Wi-Fi 5/6 on the client
([client network requirements](https://github.com/moonlight-stream/moonlight-docs/blob/eee2f08df569b2309b4e0c79e0f987559fabe0a0/wiki/Setup-Guide.md#L264-L280)).
The desktop is already wired at `192.168.1.100` with a live 2.5 Gb/s full-duplex
link. The Mac's active client link is 5 GHz Wi-Fi 6 (80 MHz, reporting 286 Mb/s),
and a direct Tailscale preflight between the two machines settled at a 3 ms
round trip. That is a strong starting network path, but the stream overlay must
still measure real packet loss, decode latency and frame pacing. Manually adding
`192.168.1.100` in Moonlight avoids ambiguity from the host's simultaneously
active Wi-Fi interface.

## Pairing and validation

1. Add the NixOS configuration, build it with
   `nh os build . -H desktop`, then activate with
   `nh os switch . -H desktop`. Log out/in or reboot once so the new `uinput`
   group is present in the graphical session.
2. Check the user service and encoder logs:

   ```console
   systemctl --user status sunshine
   journalctl --user -u sunshine -b
   ```

   The log should name `DP-2`, `/dev/dri/renderD128`, `wlgrab`/wlroots and
   working `h264_vaapi`, `hevc_vaapi` and `av1_vaapi` encoders.
3. If encoder support ever regresses after a Mesa/kernel update, re-run the
   direct device check (`,` resolves `vainfo` from `libva-utils`):

   ```console
   , vainfo --display drm --device /dev/dri/renderD128
   ```

   Look for `VAEntrypointEncSlice` on H.264 High, HEVC Main/Main10 and AV1
   Profile0. Recheck that `renderD128` is still PCI `0000:03:00.0` if GPU
   enumeration changes.
4. On the host, open `https://localhost:47990`, accept the expected self-signed
   certificate warning, and create a unique UI username/password. Anyone who
   controls this UI can authorise new remote clients, so keep it private
   ([Sunshine UI setup](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/getting_started.md#L535-L560),
   [Moonlight security warning](https://github.com/moonlight-stream/moonlight-docs/blob/eee2f08df569b2309b4e0c79e0f987559fabe0a0/wiki/Setup-Guide.md#L34-L50)).
5. Install Moonlight 6.1 on the Mac through nix-darwin (or use the official DMG
   fallback). On the same LAN, select the discovered host or manually add
   `192.168.1.100`. Moonlight displays a PIN; enter it on Sunshine's **PIN**
   page and give the Mac a recognisable name
   ([official pairing flow](https://github.com/moonlight-stream/moonlight-docs/blob/eee2f08df569b2309b4e0c79e0f987559fabe0a0/wiki/Setup-Guide.md#L38-L50)).
6. Test Remote Desktop at 1080p60/H.264 with Moonlight's performance overlay.
   Confirm keyboard, relative mouse, audio and a controller. Then try 1440p60,
   HEVC and finally 4K/AV1 one change at a time; keep the combination with low
   encode, decode and network latency rather than assuming the newest codec is
   automatically best.

## Limitations and unresolved details

- **HDR:** the 7900 XTX passed 10-bit HEVC/AV1 encoder probing, but the proven
  `wlr` path is the SDR recommendation. Pinned Sunshine requires KMS plus
  `cap_sys_admin` for experimental Linux HDR and names Gamescope or KDE Plasma
  6 as suitable HDR compositors, not this Hyprland session. HDR is therefore
  unproven on this exact desktop and would trade away the least-privilege
  configuration.
- **Mac decoder performance:** the M3 Pro explicitly supports hardware H.264,
  HEVC and AV1 decode, so codec compatibility is settled. The best codec,
  resolution, frame rate and bitrate still require an end-to-end Moonlight
  session; hardware support alone does not prove low decode latency at every
  combination.
- **Host/client display mismatch:** the host is 16:9 4K at 1.5 scale, while a
  MacBook panel is 3024x1964 with a different aspect ratio. Sunshine will stream the
  selected host output; it does not automatically make that physical display
  match every client resolution. Expect letterboxing/scaling unless a later
  virtual-output or Hyprland mode-switch workflow is added. Upstream confirms
  `wlr` can capture Hyprland virtual displays, but that is extra setup rather
  than necessary for the first stream
  ([capture setting](https://github.com/LizardByte/Sunshine/blob/v2026.516.143833/docs/configuration.md#L2093-L2097)).
- **Declarative UI trade-off:** once `settings`/`applications` are supplied by
  Nix, those sections cannot be changed through Sunshine's UI. Credentials,
  pairing and logs remain web-UI workflows.
- **Port exposure:** `openFirewall = true` includes the admin UI on all normal
  host interfaces. It does not itself create an Internet/NAT forward, and UPnP
  is disabled above, but the interface-scoped rules are the better settled
  state after the initial test.
- **Upstream tables:** Sunshine explicitly labels its requirements/compatibility
  tables work in progress. The direct local VA-API and end-to-end Sunshine
  startup checks are the basis for the positive verdict, not those tables
  alone.
