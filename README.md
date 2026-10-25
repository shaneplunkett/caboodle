# caboodle

The whole kit and caboodle: every machine Shane runs, in one repo. That's a
two-node Proxmox cluster (PVE and Cube) with a little Hetzner and Cloudflare,
plus the desktop, the Steam Deck, the MacBook and the Mac mini. Terraform creates the
containers, and Nix configures every machine. What's actually deployed is whatever the code says, so this
README only covers how the pieces fit together.

## Layout

```
flake.nix          colmena hive, dev shell, and the base LXC template
hosts/<host>.nix   what a host runs (the desktop's and the Deck's are folders)
modules/           anything more than one host can import
  homelab.nix      the homelab.* options every host declares, whatever it runs
  nixos.nix        every NixOS host: Nix settings, nh's clean, node exporter
  lxc.nix          every LXC: Proxmox LXC support, the platform, root's keys
  vm.nix           every VM: QEMU guest support, its disk image, the platform, root's keys
  darwin/          every Mac: Nix settings, the deploy user, node exporter
  agenix/          secrets, their recipients, and the homelab.secrets option
  services/<name>/ one folder per service
  workstation/     every workstation: home-manager, fish, fonts, and a folder per class
home/              Shane's home-manager configs, one per machine, and their modules
pkgs/              packages the flake builds itself, and the overlays that add them for workstations
terraform/         Proxmox LXCs/VMs, Hetzner, Cloudflare
proxmox/           config installed on the Proxmox nodes themselves
docs/              notes that the code can't explain
tools/             small helpers (minirack planner, Cloudflare MCP headers, Music Assistant's YouTube cookie)
```

## Nix hosts

Every host is a node in the colmena hive in `flake.nix`: the NixOS LXCs, the
desktop and the Macs. The hive's defaults only hold options and data, since
they have to evaluate on both systems.

A service that runs on both kinds of host keeps its options in an
`options.nix` next to its `default.nix`, so the hive can read them from any
host, and the NixOS half and the darwin half each read the same facts.

The mini is a server, deployed on merge like the LXCs; see
[docs/mini](docs/mini/README.md). The MacBook, the desktop and the Deck are
built by every pull request but switched by hand; see
[docs/macbook](docs/macbook/README.md), [docs/desktop](docs/desktop/README.md)
and [docs/deck](docs/deck/README.md). What they share is in
[docs/workstation](docs/workstation/README.md).

Modules can read the whole hive through colmena's `nodes` and `name`
arguments, so things like scrape targets, log shipping and dashboard tiles are
generated from the hive instead of kept as hand-written lists.

Every address on the LAN is written once. A host's is its
`homelab.lanAddress` in the hive. A laptop has none, and anything that walks
the hive skips it. Everything else, from the gateway and the
Proxmox nodes to the IoT devices, is in `modules/devices.nix`, and modules
read it as `config.homelab.devices.<name>.ip`. Terraform reads both through
`nix eval .#network` and reserves each address in UniFi, so adding a device is
one entry there. Keep secrets out of it: whatever Terraform reads this way
lands in its state and in the plan comments.

A service backs up its data by listing it in `homelab.backup.paths`. See
[docs/hetzner](docs/hetzner/README.md) for how that works and how to restore.

```sh
nix build --store ssh-ng://root@builder .#hydraJobs.<host>   # build on the builder
colmena apply --on <host>                                     # deploy over SSH
```

Flakes only see tracked files, so `git add` new files before building. CI
builds what a pull request changes, so the desktop needn't build at all.

### Adding a host

1. Build the template if it's changed:
   `nix build .#nixosConfigurations.base.config.system.build.tarball`, and
   upload it to each Proxmox node's `local:vztmpl` under the name
   `terraform/modules/nixos-lxc` expects.
2. Add `hosts/<host>.nix` and an entry in the hive pointing at it,
   `<host> = lxc "<host>" { homelab.lanAddress = "..."; };`. The host has
   no key until its container boots, so until step 4 lands, keep it out of
   merge deploys and monitoring with `deployment.tags = [ ];` and
   `homelab.monitoring.enable = false;`.
3. Add a `terraform/<proxmox-node>-<host>.tf` using `modules/nixos-lxc` and apply it.
   Terraform reserves the host's address in UniFi before the container first
   boots, and a host that isn't in the hive fails the plan. Leave
   `mac_address` out and Terraform makes one. Never copy one from another
   host: a duplicated MAC once had two containers fighting over one DHCP
   lease.
4. Add the host's key to `modules/agenix/host-keys.nix`
   (`ssh-keyscan -t ed25519 <ip>`), name it in `agenix-rules.nix`, add it to
   the secrets it needs, and `agenix -r` to rekey. The builder trusts hosts
   from the same file, so this is also what lets it deploy there.
5. `colmena apply --on <host>`. Colmena reaches hosts by their tailnet
   name, which doesn't exist until this first deploy joins it, so for this
   one deploy temporarily set `deployment.targetHost` to the LAN address.

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
turns `homelab.monitoring` off, as the desktop does. The Proxmox nodes are
scraped too (see [proxmox](proxmox/README.md)). Alert rules
live next to the service they watch, and everything routes through
Alertmanager to Discord. Gatus on the dashboard host watches the monitoring
stack itself, so a dead Alertmanager still gets noticed.

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

How pull requests build, merges deploy, Terraform applies and updates arrive
is in [docs/pve/builder.md](docs/pve/builder.md).

## Tools

- [minirack](tools/minirack/README.md): a visual planner for the 10" minirack
  layout and cabling. Run `bun tools/minirack/server.ts`.
- `tools/music-assistant/youtube-cookie.py`: signs in to YouTube Music in a
  throwaway Chrome profile and hands the cookie to Music Assistant. Run it
  when the YouTube Music source starts failing.
