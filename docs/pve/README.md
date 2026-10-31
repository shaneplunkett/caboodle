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

Merging builds PVE but never deploys it. It's the hypervisor and the NAS,
so a bad switch takes every guest down with it, the builder doing the
deploy included. Shane switches it by hand.

Build it on the builder, then have PVE fetch it from Attic on the cache
guest and switch:

```sh
path=$(nix build --no-link --print-out-paths --store ssh-ng://root@builder .#hydraJobs.pve)
ssh root@<pve> "nix copy --from http://192.168.1.158:8080/shane $path \
  && nix-env -p /nix/var/nix/profiles/system --set $path \
  && $path/bin/switch-to-configuration switch"
```

`<pve>` is its LAN address. The builder pushes the build to the cache a few
seconds after it lands.

- **Skip `cache.shaneplunkett.com`.** It's served through ingress, a guest
  on PVE, so it's gone whenever PVE's networking is. The cache guest's own
  address only needs the cache.
- **A host that hasn't switched since the cache moved to Attic** has
  neither its key nor its pull token. Pass both, as step 4 of adding a host
  in the [README](../../README.md#adding-a-host) does, with
  `machine 192.168.1.158` in the netrc.
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
