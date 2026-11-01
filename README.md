# caboodle

The whole kit and caboodle: every machine Shane runs, in one repo. That's PVE
and Cube, two NixOS hosts running Incus, with a little Hetzner and
Cloudflare, plus the desktop, the Steam Deck, the MacBook and the Mac mini.
Terraform creates the containers, and Nix configures every machine. What's
actually deployed is whatever the code says, so this README only covers how
the pieces fit together.

## Layout

```
flake.nix          colmena hive, dev shell, and the Incus base image
hosts/<host>.nix   what a host runs (the desktop's and the Deck's are folders)
modules/           anything more than one host can import
  homelab.nix      the homelab.* options every host declares, whatever it runs
  nixos.nix        every NixOS host: Nix settings, nh's clean, node exporter
  incus.nix        every Incus container: container support, networkd, and guest.nix
  guest.nix        every guest: the platform and root's keys
  darwin/          every Mac: Nix settings, the deploy user, node exporter
  agenix/          secrets, their recipients, and the homelab.secrets option
  services/<name>/ one folder per service
  workstation/     every workstation: home-manager, fish, fonts, and a folder per class
home/              Shane's home-manager configs, one per machine, and their modules
pkgs/              packages the flake builds itself, and the overlays that add them for workstations
terraform/         Incus containers, Hetzner, Cloudflare
docs/              notes that the code can't explain
tools/             small helpers (minirack planner, Cloudflare MCP headers, Music Assistant's YouTube cookie)
```

## Nix hosts

Every host is a node in the colmena hive in `flake.nix`: PVE, Cube, their
Incus containers, the desktop and the Macs. The hive's defaults only
hold options and data, since they have to evaluate on both systems.

A service that runs on both kinds of host keeps its options in an
`options.nix` next to its `default.nix`, so the hive can read them from any
host, and the NixOS half and the darwin half each read the same facts.

The mini is a server, deployed with `scripts/deploy.sh` like the containers; see
[docs/mini](docs/mini/README.md). PVE, Cube, the MacBook, the desktop and the
Deck are switched by hand; see
[docs/pve](docs/pve/README.md), [docs/cube](docs/cube/README.md),
[docs/macbook](docs/macbook/README.md), [docs/desktop](docs/desktop/README.md)
and [docs/deck](docs/deck/README.md).
What the workstations share is in
[docs/workstation](docs/workstation/README.md).

Modules can read the whole hive through colmena's `nodes` and `name`
arguments, so things like scrape targets, log shipping and ingress routes are
generated from the hive instead of kept as hand-written lists.

Every address on the LAN is written once. A host's is its
`homelab.lanAddress` in the hive. A laptop has none, and anything that walks
the hive skips it. Everything else, from the gateway to the IoT devices, is
in `modules/devices.nix`, and modules read it as
`config.homelab.devices.<name>.ip`. PVE and Cube are in there too, and their
hosts take their address from it. Terraform reads both through
`nix eval .#network` and reserves each address in UniFi, so adding a device
is one entry there. Keep secrets out of it: whatever Terraform reads this way
lands in its state and in the plan comments.

A service backs up its data by listing it in `homelab.backup.paths`. See
[docs/hetzner](docs/hetzner/README.md) for how that works and how to restore.

```sh
scripts/quietly.sh colmena build --on <host>   # build here, one at a time, out of the way
scripts/deploy.sh <host>                        # build and apply over SSH
scripts/deploy.sh                               # every server, dns2 after dns1
scripts/terraform.sh                            # plan; `apply` applies
```

Flakes only see tracked files, so `git add` new files before building.
Builds happen on the desktop, through the wrapper
([docs/desktop](docs/desktop/README.md#building-here)); CI only runs
`scripts/check.sh`.

### Adding a host

New hosts are Incus containers, on PVE or Cube.

1. Add `hosts/<host>.nix` and an entry in the hive pointing at it, with its
   container in `homelab.guest` (`modules/services/incus/README.md`):

   ```nix
   <host> = incus "<host>" {
     homelab.lanAddress = "...";
     homelab.guest.host = "pve";
     homelab.monitoring.enable = false;
     deployment.tags = [ ];
   };
   ```

   The host has no key until its container boots, so until step 3 lands,
   the last two lines keep it out of merge deploys and monitoring.
2. Merge it. Terraform reserves the host's address in UniFi and creates the
   container from the base image. Leave `mac` out and Terraform makes one.
   Never copy one from another host: a duplicated MAC once had two
   containers fighting over one DHCP lease. A rebuilt host can keep its own
   old MAC, and Terraform takes over its old UniFi client. A new MAC can
   boot onto a dynamic address before UniFi applies its reservation, and
   renewing keeps that lease; `incus exec <host> -- networkctl reconfigure
   eth0` on its Incus host asks afresh.
3. Add the host's key to `modules/agenix/host-keys.nix`
   (`ssh-keyscan -t ed25519 <ip>`), name it in `agenix-rules.nix`, add it to
   the secrets it needs, and `agenix -r` to rekey. Shane's key is root on
   every guest through `guest.nix`, which is what lets the desktop deploy
   there.
4. Deploy it once by hand to join Tailscale and start its services. Its
   hive name doesn't resolve until it's on the tailnet, so push the first
   build to its LAN address yourself:

   ```sh
   path=$(scripts/quietly.sh nix build --no-link --print-out-paths .#hydraJobs.<host>)
   nix copy --to ssh://root@<ip> "$path"
   ssh root@<ip> "nix-env -p /nix/var/nix/profiles/system --set $path \
     && $path/bin/switch-to-configuration switch"
   ```

   A rebuilt host joins Tailscale as `<host>-1` while its old node exists,
   so delete the old node and rename the new one in the admin console.
   Then drop step 1's guards.

## Secrets

agenix, with recipients in `modules/agenix/agenix-rules.nix`. A module asks
for secrets by name with `homelab.secrets = [ "name" ];` and reads the path
from `config.age.secrets.<name>.path`. Values come from rbw and are piped
straight in, so they never land on disk or in shell history:

```sh
cd modules/agenix
printf 'KEY=%s\n' "$(rbw get <entry>)" | agenix -e <name>.age
```

## Monitoring

Prometheus, Alertmanager, Loki and Grafana run on the monitoring host. Every
NixOS host ships its journal to Loki, and every host is scraped unless it
turns `homelab.monitoring` off, as the desktop does. Alert rules
live next to the service they watch, and everything routes through
Alertmanager to Discord. They only cover what loses data quietly: disks
filling, SMART, and backups failing or going stale. Anything else, look in
Grafana. Alertmanager's always-firing Watchdog pings healthchecks.io every
minute, so a dead Alertmanager still gets noticed.

When the internet itself is broken, see
[docs/internet-down.md](docs/internet-down.md).

## Ingress

nginx on the ingress host terminates TLS with a wildcard certificate (ACME
DNS-01 via Cloudflare) and proxies `<name>.shaneplunkett.com` to each
service. A service in the hive declares its own route with
`homelab.routes.<name> = <port>;`, and anything outside the hive is listed in
`modules/services/nginx-ingress`. Unknown names get a 404. On the LAN, Blocky
resolves the whole domain to the ingress host.

A host asks the gateway for a WAN port forward the same way:
`homelab.portForwards.<name> = <port>;` forwards that port to the same port on
the host's `lanAddress`, and Terraform makes the UniFi rule.

## Changes and deploys

CI runs `scripts/check.sh` and nothing else. Builds and deploys happen on
the desktop, through `scripts/quietly.sh`, `scripts/deploy.sh` and
`scripts/terraform.sh`; `AGENTS.md` has the routine and
[ADR 0004](docs/adr/0004-the-desktop-builds-and-deploys.md) the why.

## Tools

- [minirack](tools/minirack/README.md): a visual planner for the 10" minirack
  layout and cabling. Run `bun tools/minirack/server.ts`.
- `tools/music-assistant/youtube-cookie.py`: signs in to YouTube Music in a
  throwaway Chrome profile and hands the cookie to Music Assistant. Run it
  when the YouTube Music source starts failing.
