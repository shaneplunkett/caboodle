# Cache

Incus guest on PVE running Attic, the Nix binary cache at
`cache.shaneplunkett.com`. The service is `modules/services/attic`, from
nixpkgs' `services.atticd`, with chunks on local disk and SQLite beside
them in `/var/lib/atticd`. Nothing backs it up: a lost cache is a slow week
of rebuilding, not lost data.

## Pulls and pushes

Attic serves each cache under its own name, so the substituter is
`https://cache.shaneplunkett.com/shane`, not the bare hostname.

The hostname is only answered by Blocky, so nothing outside the LAN and the
tailnet can reach the cache. A GitHub runner on the tailnet doesn't use
Blocky, so it pulls and pushes by the guest's tailnet name,
`cache.tail1d49f8.ts.net:8080`. The builder pushes straight to port 8080 at
the guest's LAN address.

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

### Every machine pulls

`modules/services/attic/client.nix` is in every NixOS host and every Mac: it
adds the substituter, trusts the cache's key, and points Nix's
`netrc-file` at `attic-netrc`, which holds the pull token for all three
names. Nix matches a netrc entry by host alone, so the LAN address and the
tailnet name need their own lines.

The netrc is readable by `wheel`, or `admin` on a Mac, because `nix copy
--from` fetches in the client, not the daemon, so a by-hand fetch as
Shane needs the token too.

The Macs run agenix for this, and decrypt with
`/etc/ssh/ssh_host_ed25519_key`.

### The builder pushes

`attic-watch-store` on the builder pushes every path that lands in its
store, so every job's build and every by-hand build is cached a few seconds
later. That includes everything the builder substitutes, so the cache
lists the keys of the caches the builder pulls from as upstream:
cache.nixos.org, nix-community, noctalia and numtide. A push leaves out
anything one of them signed. `--ignore-upstream-cache-filter` overrides
that for one push.

### GitHub runners push

A GitHub job that builds a host, in workflows' `hosts.yml`, pushes the
closure with `attic push` straight after the build, because the runner's
store is gone when the job ends. It reaches the guest by its tailnet name,
pulls with the pull token in Nix's netrc, and keeps the push token in the
push step alone. The push leaves out anything an upstream signed, as the
builder's does. The builder doc's [Building on GitHub](builder.md#building-on-github)
has the rest.

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
with the server's config and secret. They live in Bitwarden as
`attic-push-token` and `attic-pull-token`, and in agenix as
`attic-push-token` and `attic-netrc`:

```sh
ssh root@cache atticd-atticadm make-token --sub push --validity 10y --pull shane --push shane \
  | tail -1 | rbw add attic-push-token
ssh root@cache atticd-atticadm make-token --sub pull --validity 10y --pull shane \
  | tail -1 | rbw add attic-pull-token
```

They last ten years because nothing alerts on an expired token: CI would
just start failing its pushes one day.

caboodle's GitHub Actions secrets hold them as `ATTIC_PULL_TOKEN` and
`ATTIC_PUSH_TOKEN`, for the runners. A new token goes there too:

```sh
printf '%s' "$(rbw get attic-pull-token)" | gh secret set ATTIC_PULL_TOKEN --repo shaneplunkett/caboodle
printf '%s' "$(rbw get attic-push-token)" | gh secret set ATTIC_PUSH_TOKEN --repo shaneplunkett/caboodle
```

## Setting it up

The cache itself is database state, not config, so a rebuilt guest needs it
made again. From the guest, with a short-lived admin token:

```sh
admin=$(atticd-atticadm make-token --sub shane --validity 1h --pull shane --push shane \
  --create-cache shane --configure-cache shane --configure-cache-retention shane)
nix shell nixpkgs#attic-client -c sh -c "
  attic login home http://192.168.1.158:8080 $admin
  attic cache create home:shane
  attic cache configure home:shane \
    --upstream-cache-key-name cache.nixos.org-1 \
    --upstream-cache-key-name nix-community.cachix.org-1 \
    --upstream-cache-key-name noctalia.cachix.org-1 \
    --upstream-cache-key-name niks3.numtide.com-1
  attic cache info home:shane"
```

`cache info` prints the public key every machine trusts, which goes in
`client.nix`. A new cache gets a new key.

- **`cache configure` needs `--configure-cache-retention`** even when it
  leaves retention alone, because the client always sends the retention
  setting. Without it the server says `User does not have permission`.
- **The cache is private**, so a pull needs the pull token as well.
  Closures hold builds of the private repos, and a public cache would hand
  any of them to whoever knows the store path.

## Seeding from the builder

Every host's latest build is rooted on the builder, so one push warms the
cache with all of them. The token goes in through stdin, so it never sits
in a process list:

```sh
rbw get attic-push-token | ssh root@builder 'set -e
  d=/root/attic-seed; mkdir -p -m 700 $d/.config/attic
  printf "default-server = \"home\"\n[servers.home]\nendpoint = \"http://192.168.1.158:8080/\"\ntoken = \"%s\"\n" \
    "$(cat)" > $d/.config/attic/config.toml
  attic=$(nix build --no-link --print-out-paths nixpkgs#attic-client)/bin/attic
  systemd-run --unit attic-seed -p Environment=HOME=$d --collect sh -c \
    "$attic push shane -j 8 $(readlink -f /var/lib/forgejo-runner/builder/roots/caboodle/* | tr "\n" " "); $(command -v rm) -rf $d"'
```

Follow it with `journalctl -fu attic-seed` on the builder.

- **The unit has no `rm` on its `PATH`**, so the command passes the
  outer shell's. Not through `readlink -f`: that lands on coreutils'
  multi-call binary, which doesn't know it was called as `rm`.
- **Restarting `atticd` fails every upload in flight**, and the push
  exits with them. Run it again; it skips whatever's already cached. A
  deploy changes `atticd`'s unit before the old process has stopped, so
  wait for `ActiveEnterTimestamp` to move, not for the new config.

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
