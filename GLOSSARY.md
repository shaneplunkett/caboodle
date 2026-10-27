# caboodle

Every machine Shane runs, configured from one repo: PVE and its Incus containers, Cube and its Proxmox LXCs, Hetzner and Cloudflare, plus the desktop, the Deck, the MacBook and the Mac mini.

## Language

**caboodle**:
The repo that configures every machine Shane runs. It deploys services but doesn't own them.
_Avoid_: homelab

**Service**:
Something a server runs for Shane, like the forge, Pocket ID or Immich. It's hers, used by her and her other projects; caboodle only deploys it.

## Machines

**Host**:
A machine Nix configures as a member of the colmena hive: PVE, a guest, the desktop, the Deck or a Mac.
_Avoid_: node, hive node

**Server**:
A host that runs services: PVE, every guest, and the mini. All but PVE deploy when a pull request merges. The mini is a workstation too.

**Workstation**:
A host that carries Shane's own setup: home-manager, fish and fonts. The desktop, the MacBook and the mini.
_Avoid_: machine Shane sits at

**Guest**:
A host that runs in a container on another machine: an Incus container on PVE, or a Proxmox LXC on Cube.

**Proxmox node**:
Cube, the one physical Proxmox machine left, which runs the LXCs. It's a device, not a host. PVE was one until it became a NixOS host.
_Avoid_: bare "node"

**Device**:
Something on the LAN with a reserved address that isn't a host, like the gateway, Cube or a smart plug. Each one is listed in `modules/devices.nix`.

## Changes

**Derivation diff**:
The hosts whose built system differs between a pull request's base and its head. It's the list of what a merge would rebuild.
_Avoid_: host diff, affected hosts
