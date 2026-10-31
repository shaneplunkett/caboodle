# Cache

Incus guest on PVE running Attic, the Nix binary cache taking over
`cache.shaneplunkett.com` from Harmonia on the [builder](builder.md). The
service is `modules/services/attic`, from nixpkgs' `services.atticd`, with
chunks on local disk and SQLite beside them in `/var/lib/atticd`. Nothing
backs it up: a lost cache is a slow week of rebuilding, not lost data.

Until the swap lands, Harmonia still answers the hostname and Attic is only
reachable on port 8080.

## Pulls and pushes

Attic serves each cache under its own name, so the substituter is
`https://cache.shaneplunkett.com/shane`, not the bare hostname.

The hostname is only answered by Blocky, like Harmonia's, so nothing
outside the LAN and the tailnet can reach the cache. A GitHub runner on the
tailnet doesn't use Blocky, so it pulls and pushes by the guest's tailnet
name, `cache.tail1d49f8.ts.net:8080`. The builder pushes straight to port
8080 at the guest's LAN address.

- **`api-endpoint` is unset on purpose.** A push first asks the server for
  the cache's config, then sends everything to the `api-endpoint` that
  comes back. Set to the hostname, a runner would be sent to a name it
  can't resolve. Unset, Attic builds it from the request's `Host`, so each
  pusher keeps the address it logged in with.
- **`allowed-hosts` lists the three names it answers to**, so a forged
  `Host` is refused instead of echoed back as the endpoint. Reaching it by
  `localhost` fails with `Bad Host`; use the LAN address, even on the guest.
- **`substituter-endpoint` is the hostname**, which is what `attic use`
  writes into a client's `nix.conf`.

## Tokens

Tokens are JWTs signed with the RS256 key in `attic-env`. That key lives only
in agenix: Bitwarden refuses it with a 400, because a 4096-bit key is too
long for a password. If it's lost, make a new one and mint the tokens again,
since every token dies with the key:

```sh
cd modules/agenix
nix shell nixpkgs#openssl -c sh -c 'printf "ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=%s\n" \
  "$(openssl genrsa -traditional 4096 2>/dev/null | base64 -w0)"' | agenix -e attic-env.age
```

Mint tokens on the guest with the module's wrapper, which runs `atticadm`
with the server's config and secret:

```sh
ssh root@cache atticd-atticadm make-token --sub push --validity '10y' --pull shane --push shane
ssh root@cache atticd-atticadm make-token --sub pull --validity '10y' --pull shane
```

They last ten years because nothing alerts on an expired token: CI would
just start failing its pushes one day.

## Setting it up

The cache itself is database state, not config, so a rebuilt guest needs it
made again. From the guest, with a short-lived admin token:

```sh
admin=$(atticd-atticadm make-token --sub shane --validity '1h' \
  --pull shane --push shane --create-cache shane --configure-cache shane)
nix shell nixpkgs#attic-client -c sh -c "
  attic login home http://192.168.1.158:8080 $admin
  attic cache create home:shane
  attic cache info home:shane"
```

`cache info` prints the public key every machine trusts. A new cache
names `cache.nixos.org-1` as its upstream key, so a push leaves out
anything signed by it. `--ignore-upstream-cache-filter` overrides that for
one push.

The cache is private, so a pull needs the pull token as well. Closures
hold builds of the private repos, and a public cache would hand any of them
to whoever knows the store path.

## Seeding from the builder

Every host's latest build is rooted on the builder, so one push warms the
cache with all of them:

```sh
ssh root@builder
nix shell nixpkgs#attic-client -c sh -c '
  attic login home http://192.168.1.158:8080 <push token>
  attic push home:shane $(readlink -f /var/lib/forgejo-runner/builder/roots/caboodle/*)'
```

## Garbage collection

Attic collects inside its own process every 12 hours, so there's no systemd
timer to look for; the journal of `atticd` shows each run. An object goes
once it was both pushed and last pulled more than six weeks ago
(`default-retention-period`, which the cache inherits). Every weekly flake
update replaces nearly every closure, so six weeks keeps about six
generations of each host to roll back to, or to switch a machine that's
fallen behind, and the disk only has to hold that many.

## Chunking is off

`nar-size-threshold = 0` stores each NAR whole, as one file and a few rows.
Attic's default cuts every NAR into 64 KiB chunks so versions of a package
can share the parts that didn't change, and it only ever saves disk: pushes
and pulls still move whole NARs. It cost more than it saved here:

- **Every chunk is three separately committed SQLite writes**, each an
  fsync, and SQLite has one writer. The NVMe under PVE takes about 6 ms per
  fsync, so the first seed crawled at 2 to 3 MB/s, and a nixpkgs bump would
  push about as much again every week.
- **Nix scatters store hashes through its outputs.** A new dependency
  rewrites its path into every file that refers to it, so an unchanged
  package still differs all through, and few chunks match between versions.
  At 9.4 GB into the first seed, the unique chunks added up to more than the
  NARs; the 3x saving on disk was all zstd, which stays on.

Identical NARs are still stored once. The chunks from before the change
stay valid and are collected like anything else.
