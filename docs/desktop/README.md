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

## Game streaming

Sunshine streams the desktop to Moonlight on the Macs, over the LAN or
Tailscale. Its admin UI only answers on the desktop itself, at
`https://localhost:47990`. Give it a unique username and password, since
whoever controls it can pair new clients. Moonlight shows a PIN, which goes
on the UI's PIN page.

- If encoding breaks after a Mesa or kernel update,
  `, vainfo --display drm --device /dev/dri/renderD128` should list
  `VAEntrypointEncSlice` for H.264, HEVC and AV1. `renderD128` has to stay
  the discrete GPU; the iGPU is `renderD129`.
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
