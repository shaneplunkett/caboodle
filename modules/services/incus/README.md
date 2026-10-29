# Incus

Runs Incus on a NixOS host, with a bridge onto the LAN and an LVM-thin pool
for the guests' disks. `virtualisation.incus.preseed` sets up the pool and
the `default` profile, so they come from Nix rather than `incus admin init`.

## Storage

The host's disko makes an empty LVM volume group called `incus`, and the
pool's `source` names that group rather than a partition. Once it creates a
pool, Incus records its source as the group's name, so a preseed naming the
partition fails on every run after the first ("Pool source cannot be
changed"), and never reaches the profile.

## Terraform's access

Terraform talks to Incus over HTTPS on port 8443 with a client certificate.
`terraform.crt` is that certificate, and its key is the runner's
`terraform-incus-key` secret. `incus-trust-terraform` adds the certificate
to the trust store if it isn't there.

The preseed has a `certificates` section, but it isn't used here. Incus
creates each certificate on every run and fails once it exists, so the
preseed unit would fail on every boot after the first.

To replace the pair, from `modules/agenix`:

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -nodes \
  -days 3650 -subj /CN=terraform -keyout /dev/stdout \
  -out ../services/incus/terraform.crt \
  | RULES=./agenix-rules.nix nix develop ../.. -c agenix -e terraform-incus-key.age
```

Then remove the old certificate with `incus config trust remove`, since the
unit only adds.

## Guests

A guest is a hive node with `homelab.guest` set, which names its Incus host
and its size. `network.guests` exports them, and `terraform/incus.tf`
creates each container from the base image with its UniFi reservation. The
container's name is the node's name, and NixOS leaves the hostname to Incus.

The base image is `nixosConfigurations.incus-base`, built on the runner by
`scripts/incus-image.sh`. A guest only uses it once, when it's created, so
Terraform ignores newer builds. To refresh it, run
`terraform apply -replace='incus_image.nixos["<host>"]'`.

`running = false` creates the container without starting it. Use it when a
guest takes over another's MAC, so the two never share the LAN.

`mounts` bind-mounts host directories into the guest as Incus `disk`
devices, and `devices` passes character devices through as `unix-char`
ones, with `gid` owning the device inside, like plex's Quick Sync
`renderD128`. Both are named after their path, so `/mnt/media` is the
device `mnt-media`. Guests are unprivileged and nothing is shifted, so a
mounted file whose owner the guest can't map shows as `nobody`.

## Metrics

Prometheus scrapes each guest's CPU from Incus's `/1.0/metrics` on port
8443. The preseed turns off authentication on that endpoint only, so it
needs no certificate. The rest of the API still wants one.

Node exporter's CPU figures inside a guest are not the guest's own. lxcfs
narrows `/proc/stat` to the guest's pinned CPUs, but on cgroup v2 the times
are the host's, so a guest sharing CPUs with the builder looks as busy as
the builder. The CPU alert and the dashboard read Incus instead.

The pool alerts read Incus's pool size and used bytes, which for LVM are the
thin pool's data use, the same as `lvs`. Two gaps need covering beside them.
When Incus fails to read a pool it leaves the pool out and the scrape still
succeeds, so `IncusPoolMetricsMissing` watches for each preseed pool's series
going missing. Incus doesn't report the thin pool's metadata, which breaks
the pool just as surely when it fills, so `incus-thinpool-metrics` writes
both percentages from `lvs` into node exporter's textfile directory every
minute.

## Looking after a guest

On the guest's Incus host:

- `incus restart <guest>` restarts it.
- `incus exec <guest> -- bash` opens a shell, even when the guest's network
  or SSH is down.

To resize one, change `cores`, `memory` or `disk` in its `homelab.guest`
and merge. Terraform applies it before any host deploys.

Incus keeps no snapshots or backups of its own. What's worth keeping is in
each service's `homelab.backup.paths`, which restic sends offsite, so a dead
guest is made again by Terraform and restored from there
([hetzner](../../../docs/hetzner/README.md#restoring-a-hosts-data)).

## Moving or rebuilding a guest

A guest keeps its identity through a tar of its host keys and `/var/lib`,
so nothing is rekeyed or restored from backup. That's how PVE's and Cube's
guests left Proxmox, and it's how a guest comes back after its host is
reinstalled. It suits a guest whose state all lives in `/var/lib`. Its
`mounts` and `devices` come from `homelab.guest`, and the host needs the
mounts' sources before the guest starts. It takes two pull requests, and
nothing else merges between them.

The builder can't move this way, since the restore fetches from its
Harmonia. It moved by taking only its host keys and `/var/lib/tailscale`,
then building its own system once it was up.

1. On the guest's host, stop the guest's apps, alloy and tailscaled with
   `incus exec`, then tar its host keys and `/var/lib`. When the host itself
   is about to be reinstalled, write the tar somewhere else, like the NAS:

   ```sh
   incus exec <guest> -- bash -c 'cd / && tar --numeric-owner \
     --exclude=var/lib/systemd --exclude=var/lib/containers \
     -cpf - etc/ssh/ssh_host_* var/lib' > <dir>/<guest>.tar
   tar -tf <dir>/<guest>.tar | head -20 | grep ssh_host_
   incus stop <guest>
   ```

   The `cd /` matters: the glob is expanded before tar's `-C` applies, so
   without it the keys are silently left out. Check they're in the tar
   before going on, since without them the guest can't decrypt its secrets.

2. The first pull request gives the node its `homelab.guest` with its old
   MAC and `running = false`. Merging creates the container, stopped.
3. Build the second pull request's system on the builder before it merges
   (`.#hydraJobs.<guest>`). On the new host, restore the tar and switch the
   guest to that system, with the cache's key from
   `modules/workstation/nix-settings.nix`:

   ```sh
   incus start <guest>
   incus exec <guest> -- tar -C / --numeric-owner -xpf - < <dir>/<guest>.tar
   incus exec <guest> -- bash -lc "nix copy --from http://<builder>:5000 $path \
     --option extra-trusted-public-keys <key> \
     && nix-env -p /nix/var/nix/profiles/system --set $path \
     && $path/bin/switch-to-configuration switch"
   ```

4. The second pull request drops `running = false`, and anything else that
   changed for the guest.

Why it works:

- `/var/lib/nixos` keeps the uids and gids, so the files still belong to
  the right users.
- The old host keys mean agenix needs no rekey.
- `/var/lib/tailscale` keeps the tailnet node, so it isn't `<guest>-1`.
- Postgres is copied raw while it's stopped, so there's no dump and restore.

Gotchas:

- **A merge redeploys every running guest.** On Cube's install day a merge
  restarted Plex while it was being tarred. Nothing merges while a guest is
  being tarred or restored.
- **tar's "file changed as we read it" means something's still running.**
  It exits 1. Stop whatever restarted, and tar again.
- **Run long copies as systemd units,** with `systemd-run`, so a dropped
  SSH session doesn't take them with it. A unit's `PATH` on NixOS lacks
  `/run/current-system/sw/bin`, so give it one.
- **Never fetch from `cache.shaneplunkett.com` while moving ingress.** The
  cache is served through ingress, and fetching from it mid-move took
  everything web down for 4 minutes. Go to Harmonia on the builder directly.
- **Don't SSH over Tailscale to a host and stop its tailscaled.** Use the
  LAN address.
- **Podman images pinned by tag can be left out.** They pull again on
  start, which is why the tar skips `var/lib/containers`.
- **An interface name an app saves must stay the same.** Home Assistant
  saves `eth1`, so home's VLAN leg is still `eth1`.

## VLANs

`br0` filters by VLAN, like a VLAN-aware bridge. The uplink
carries VLAN 1 untagged, which is the LAN the host and most guests sit on,
and every other VLAN tagged. A guest joins one with `vlan` on its NIC, so a
new VLAN needs no change on the host.

networkd removes any VLAN on a port that its `.network` file doesn't list, so
only the uplink has `bridgeVLANs`. The guests' ports are Incus's to manage,
and no `.network` file matches them.

## TUN

The `default` profile hands every guest `/dev/net/tun`, so Tailscale runs in
kernel mode.
