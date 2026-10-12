# Homelab

Infrastructure for a two-node Proxmox cluster (PVE and Cube) plus a little
Hetzner and Cloudflare. Terraform creates the containers, Nix configures what
runs inside them. What's actually deployed is whatever the code says, so this
README only covers how the pieces fit together.

## Layout

```
flake.nix          colmena hive, dev shell, and the base LXC template
modules/
  base.nix         every NixOS LXC: Proxmox LXC support, SSH, node exporter
  agenix/          secrets, their recipients, and the homelab.secrets option
  hosts/<host>.nix which services a host runs
  services/<name>/ one folder per service
terraform/         Proxmox LXCs/VMs, Hetzner, Cloudflare
proxmox/           config installed on the Proxmox nodes themselves
docs/              notes that the code can't explain
tools/             small helpers (minirack planner, Cloudflare MCP headers)
```

## Nix hosts

Each NixOS LXC is a node in the colmena hive in `flake.nix`. Defaults every
node gets live in `colmenaHive.defaults`; a host's own file under
`modules/hosts/` just imports the services it runs.

Modules can read the whole hive through colmena's `nodes` and `name`
arguments, so things like scrape targets, log shipping and dashboard tiles are
generated from the hive instead of kept as hand-written lists.

Every address on the LAN is written once. A host's is its
`homelab.lanAddress` in the hive. Everything else, from the gateway and the
Proxmox nodes to the IoT devices, is in `modules/devices.nix`, and modules
read it as `config.homelab.devices.<name>.ip`. Terraform reads both through
`nix eval .#network` and reserves each address in UniFi, so adding a device is
one entry there. Keep secrets out of it: whatever Terraform reads this way
lands in its state and in the plan comments.

A service backs up its data by listing it in `homelab.backup.paths`. See
[docs/hetzner](docs/hetzner/README.md) for how that works and how to restore.

```sh
colmena build --on <host>   # check it evaluates and builds
colmena apply --on <host>   # deploy over SSH
```

Flakes only see tracked files, so `git add` new files before building.

### Adding a host

1. Build the template if it's changed:
   `nix build .#nixosConfigurations.base.config.system.build.tarball`, and
   upload it to each node's `local:vztmpl` under the name
   `terraform/modules/nixos-lxc` expects.
2. Add `modules/hosts/<host>.nix` and a node in the hive pointing at it,
   with the host's `homelab.lanAddress`.
3. Add a `terraform/<node>-<host>.tf` using `modules/nixos-lxc` and apply it.
   Terraform reads every LAN address from the hive (`nix eval
   .#network`) and reserves the host's in UniFi before the container
   first boots, so it comes up on that address. Leave `mac_address` out and
   Terraform makes one. A host that isn't in the hive fails the plan.
4. Add the host's key to `modules/agenix/host-keys.nix`
   (`ssh-keyscan -t ed25519 <ip>`), name it in `agenix-rules.nix`, add it to
   the secrets it needs, and `agenix -r` to rekey. The builder trusts hosts
   from the same file, so this is also what lets it deploy there.
5. `colmena apply --on <host>`. Colmena reaches hosts by their tailnet
   name, which doesn't exist until this first deploy joins it, so for this
   one deploy temporarily set `deployment.targetHost` to the LAN address.
6. `colmena apply --on builder`, so its SSH config and known hosts include
   the new host. Until then, every merge deploy fails to reach it.

## Secrets

agenix, with recipients in `modules/agenix/agenix-rules.nix`. A module asks
for secrets by name with `homelab.secrets = [ "name" ];` and reads the path
from `config.age.secrets.<name>.path`. Values come from rbw and are piped
straight in, so they never land on disk or in shell history:

```sh
cd modules/agenix
printf 'KEY=%s\n' "$(rbw get <entry>)" | agenix -e <name>.age
```

Whether a secret is a raw value or a `KEY=value` env file depends on what the
consuming service expects.

## Monitoring

Prometheus, Alertmanager, Loki and Grafana run on the monitoring host. Every
Nix host is scraped and ships its journal to Loki automatically, and the
Proxmox nodes are scraped too (see [proxmox](proxmox/README.md)). Alert rules
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

The forge is the source of truth, and GitHub is a push mirror of it. Every
pull request builds every host on the builder, and every push to `main`
deploys every host tagged `deploy-on-merge`, one deploy at a time, then
dns2 once dns1 is answering. That includes the builder, whose runner restarts
gracefully after the deploy rather than during it; see
[builder.md](docs/pve/builder.md).

Terraform works the same way: a pull request touching `terraform/` gets its
plan posted as a comment, and merging applies it, before any host deploys. See
[docs/pve/builder.md](docs/pve/builder.md).

Updates are a pull request like any other: `nix flake update`, push a
branch, and merge once it builds.

## Tools

- [minirack](tools/minirack/README.md): a visual planner for the 10" minirack
  layout and cabling. Run `bun tools/minirack/server.ts`.
