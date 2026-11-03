# Cache

Incus guest on PVE whose store takes built closures, served read-only by
Harmonia, so every host pulls instead of building. The service is
`modules/services/harmonia`. It's a shelf: no database, no tokens and no
uploads. [ADR 0005](../adr/0005-merges-deploy-from-a-runner-at-home.md) has
why it isn't Attic or the runner's own store. Losing the guest costs a slow
week, so it has no backups. Terraform makes it again and the next pushes
refill it.

## Pushing

```sh
scripts/push-to-cache.sh plex rss
```

For each host, that builds through `scripts/quietly.sh`, runs
`nix copy --to ssh-ng://root@cache`, and sets
`/nix/var/nix/profiles/per-host/<host>` on the cache. Root is a trusted user
over `ssh-ng`, so a push needs no signature. Harmonia signs each path as it
serves it, with the agenix key `nix-store-key-cache`.

There's no `--substitute-on-destination`, so a push never depends on the
cache's internet.

To see what's there:

```sh
ssh root@cache nix-env -p /nix/var/nix/profiles/per-host/rss --list-generations
nix path-info --store http://cache.home.arpa:5000 --sigs <path>
```

## Pulling

`client.nix` lists the cache as a substituter and trusts its key. `nixos.nix`
and `darwin/` both import it, so it reaches every host, including the base
image.

Harmonia advertises priority 30 and cache.nixos.org advertises 40, and Nix
tries the lower number first. The NixOS module's default is 50, which would
send every shared path to the internet.

`colmena apply` copies with substitutes on, so `scripts/deploy.sh` pulls from
the cache too. To watch a host fetch a closure:

```sh
path=$(ssh root@cache readlink -f /nix/var/nix/profiles/per-host/rss)
ssh root@rss nix-store -r "$path"
```

Each path prints `copying path '...' from 'http://cache.home.arpa:5000'`. A
host already running that closure prints nothing, since it has every path.

## The name

Pulls use `cache.home.arpa`, and Blocky is the only thing that answers for
it.

The bare `cache` doesn't work on servers. Hive names come from MagicDNS, and
servers run with `--accept-dns=false`. systemd-resolved doesn't send
single-label names to a DNS server either, so `resolvectl query ingress` on
a guest says not found.

The LAN gets Blocky from DHCP. The tailnet gets it because the DNS hosts are
its global nameservers. `home.arpa` is reserved for home networks (RFC 8375),
so nothing public can answer for it. The address is private with no port
forward, and there's no route in `homelab.routes`, so nothing outside can
reach it. That's why pulls need no authentication.

A client away from home reaches the address through PVE's subnet route if it
accepts routes, which Macs do. One that doesn't times out and carries on as
if the cache were down.

Pushes do use `cache`, over SSH, because the desktop has MagicDNS and
`known_hosts` has the key under that name.

## Disk

`nix copy` ships whole closures with no upstream filter, so the store is
large. It lives in the `nas-cache` pool, a btrfs subvolume at
`/mnt/cache/incus` on the NAS's NVMe, because the default pool is on the root
disk.

The mover only walks `Media`, `Programs` and `Games`, so it never touches the
pool. The same drive is where `/mnt/user` puts new files first, though, and
mergerfs stops using it at 100 GB free. `disk = 300` caps the guest so the
store can't eat that landing zone. A full cap still takes 300 GiB of room from
incoming media, which is the trade. Bump it if pushes hit the cap and the
drive has room.

The cap has costs:

- **It turns on btrfs quotas for the whole drive.** The first time Incus sets
  a size on this driver it runs `btrfs quota enable` and a rescan, so every
  write to `/mnt/cache`, media included, gets accounted from then on. Removing
  the cap and running `btrfs quota disable /mnt/cache` undoes it without
  touching data.
- **Nothing inside the guest can see the cap.** `df` there shows the whole
  drive, so node exporter's disk alert reads the drive too. Hitting the cap
  shows up as `Disk quota exceeded` from `nix copy`.
- **`IncusPoolFilling` reads the whole drive too**, media included, and its
  `lvs` hint doesn't apply to this pool. Look at `btrfs filesystem df
  /mnt/cache` instead.

## Garbage collection

`nix.gc` runs weekly with `--delete-older-than 7d`. For each host's profile
that keeps the last 7 days of generations, the generation that was live 7 days
ago, and the current one. A host nobody has pushed for months keeps its last
closure.

`nh clean` is off on this one host, because `nh clean all` only looks at
symlinks directly in `/nix/var/nix/profiles` and in `per-user/*`. It never
sees `per-host`, so those generations would stay forever.
`nix-collect-garbage` walks the profile directories all the way down. The two
also warn if both are on.

`nix-env` fails if the profile's directory is missing, so tmpfiles makes
`per-host`.

## When it's down

A switch gets slower and still works. `connect-timeout = 5` and
`fallback = true` are in `client.nix`. With the guest stopped, or its address
silent, Nix tries the first path five times, benches the cache for 60 seconds,
and carries on with everything else:

```
warning: unable to download 'http://cache.home.arpa:5000/<hash>.narinfo': Timeout was reached (28) Connection timed out after 5000 milliseconds; retrying in 282 ms (attempt 1/5)
...
disabling binary cache 'http://cache.home.arpa:5000' for 60 seconds
error: unable to download 'http://cache.home.arpa:5000/<hash>.narinfo': ...
copying path '...' from 'https://cache.nixos.org'...
```

That `error:` is only logged, and the run carries on. It costs about 30
seconds, and again each minute while the switch runs. When the name doesn't
resolve or the port refuses, it's quicker.

Both settings earn their place. Without `fallback` the cache never gets
benched, so every path retries five times. Without `connect-timeout` each try
at a silent address waits out curl's default of 5 minutes.

Both apply to every substituter, not just this one. `fallback` also means a
path that fails to fetch gets built locally rather than failing the switch.

## Gotchas

- **Nix remembers a miss for an hour** (`narinfo-cache-negative-ttl`). A host
  that asks for a path before it's pushed won't look on the cache for it again
  for an hour, so push before applying.
- **The cache lists itself as a substituter**, like every host. It only asks
  for paths it doesn't have, gets a 404, and moves on.
- **Darwin closures can't come from the desktop.** The script is Linux only,
  and a Mac's closure is pushed from the mini.
- **To replace the key**, generate a new one and put its public half in
  `cache.nix`. Hosts stop trusting the old one as they switch, so pulls
  fall back until they all have.

  ```sh
  cd modules/agenix
  nix key generate-secret --key-name cache-2 | agenix -e nix-store-key-cache.age
  agenix -d nix-store-key-cache.age | nix key convert-secret-to-public
  ```
