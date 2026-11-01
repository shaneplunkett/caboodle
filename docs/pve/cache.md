# Cache

Incus guest on PVE running Attic, the Nix binary cache at
`cache.shaneplunkett.com`. The service is `modules/services/attic`, from
nixpkgs' `services.atticd`, with NARs on local disk and SQLite beside them
in `/var/lib/atticd`. Until the GitHub cutover, every host pulls from it and
the builder pushes to it. Nothing backs it up: a lost cache is a slow week
of rebuilding, not lost data.

## Pulls and pushes

Attic serves each cache under its own name, so the substituter is
`https://cache.shaneplunkett.com/shane`, not the bare hostname. Only Blocky
answers that name, so nothing outside the LAN and the tailnet reaches the
cache. GitHub's check job joins the tailnet and pulls the dev shell by the
guest's tailnet name, `cache.tail1d49f8.ts.net:8080`, since it doesn't use
Blocky.

`modules/services/attic/client.nix` is in every NixOS host and every Mac:
it adds the substituter, trusts the cache's key, and points Nix's
`netrc-file` at `attic-netrc`, which holds the pull token. The Macs run
agenix for this, and decrypt with `/etc/ssh/ssh_host_ed25519_key`.

`attic-watch-store` on the builder pushes every path that lands in its
store. The cache lists the keys of the caches the builder pulls from as
upstream (cache.nixos.org, nix-community, noctalia and numtide), and a push
leaves out anything one of them signed. `--ignore-upstream-cache-filter`
overrides that for one push.

- **`api-endpoint` is unset on purpose.** A push first asks the server for
  the cache's config, then sends everything to the `api-endpoint` that
  comes back. Set to the hostname, a pusher off Blocky would be sent to a
  name it can't resolve. Unset, Attic builds it from the request's `Host`.
- **`allowed-hosts` lists the three names it answers to**, so a forged
  `Host` is refused instead of echoed back as the endpoint. Reaching it by
  `localhost` fails with `Bad Host`; use the LAN address, even on the guest.
- **Nix matches a netrc entry by host alone**, so the hostname, the LAN
  address and the tailnet name each need their own line.
- **The netrc is readable by `wheel`, or `admin` on a Mac**, because
  `nix copy --from` fetches in the client, not the daemon, so a by-hand
  fetch as Shane needs the token too.
- **Restarting `atticd` fails every upload in flight.** Push again; it
  skips whatever's already cached. A deploy changes the unit before the old
  process has stopped, so wait for `ActiveEnterTimestamp` to move, not for
  the new config.

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
`attic-push-token` and `attic-pull-token`, in agenix as `attic-push-token`
and `attic-netrc`, and the pull token in caboodle's GitHub Actions secrets
as `ATTIC_PULL_TOKEN`:

```sh
ssh root@cache atticd-atticadm make-token --sub push --validity 10y --pull shane --push shane \
  | tail -1 | rbw add attic-push-token
ssh root@cache atticd-atticadm make-token --sub pull --validity 10y --pull shane \
  | tail -1 | rbw add attic-pull-token
printf '%s' "$(rbw get attic-pull-token)" | gh secret set ATTIC_PULL_TOKEN --repo shaneplunkett/caboodle
```

They last ten years because nothing alerts on an expired token: pushes
would just start failing one day.

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

## Garbage collection

Attic collects inside its own process every 12 hours, so there's no systemd
timer to look for; the journal of `atticd` shows each run. An object goes
once it was both pushed and last pulled more than six weeks ago
(`default-retention-period`). Every weekly flake update replaces nearly
every closure, so that keeps about six generations of each host to roll
back to.

## Chunking is off

`nar-size-threshold = 0` stores each NAR whole. Attic's default cuts NARs
into 64 KiB chunks so versions of a package can share parts, but it only
ever saves disk, and here it cost more than it saved. Every chunk is three
separately committed SQLite writes on an NVMe that takes about 6 ms per
fsync, so the first seed crawled at 2 to 3 MB/s. And Nix scatters store
hashes through its outputs, so an unchanged package still differs all
through and few chunks match between versions: the 3x saving was all zstd,
which stays on. Identical NARs are still stored once.
