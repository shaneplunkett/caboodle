# PVE

## Summary

NixOS host that runs the Incus guests and is the NAS. Its config is
`hosts/pve`. How Incus is set up, and how to look after a guest, is in
[incus](../../modules/services/incus/README.md).

Per-service docs:

- [auth.md](auth.md)
- [brain.md](brain.md)
- [builder.md](builder.md)
- [cache.md](cache.md)
- [forge.md](forge.md)
- [home.md](home.md)
- [mirror.md](mirror.md)
- [recipes.md](recipes.md)
- [rss.md](rss.md)

## Deploying

Nothing deploys PVE. It's the hypervisor and the NAS, so a bad switch takes
every guest down with it. Shane switches it by hand.

Build it on the desktop, push the closure to PVE over SSH, and switch:

```sh
path=$(scripts/quietly.sh nix build --no-link --print-out-paths .#hydraJobs.pve)
nix copy --to ssh://root@<pve> "$path"
ssh root@<pve> "nix-env -p /nix/var/nix/profiles/system --set $path \
  && $path/bin/switch-to-configuration switch"
```

`<pve>` is its LAN address. Nothing in the path depends on a guest, so this
works with PVE's networking half up.

- **SSH in over the LAN, not Tailscale.** A switch can restart tailscaled
  and drop the session halfway.

## Changing the network

A mistake in `br0` or the uplink cuts PVE off the LAN, and SSH with it, so
the only way back is a keyboard. Arm a rollback before trying the new
system, and only switch for good once it works. On PVE, with `$path` the
new system already fetched:

```sh
old=$(readlink -f /run/current-system)
systemd-run --on-active=240 --unit=rollback $old/bin/switch-to-configuration test
$path/bin/switch-to-configuration test
```

From a new SSH session, check PVE and a guest or two still answer. Then
cancel the rollback and switch:

```sh
systemctl stop rollback.timer
nix-env -p /nix/var/nix/profiles/system --set $path
$path/bin/switch-to-configuration switch
```

`test` leaves the boot entry alone, so if the timer doesn't save it, a
reboot still comes back on the old system.
