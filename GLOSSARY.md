# caboodle

Every machine Shane runs, configured from one repo: PVE and Cube and their Incus containers, Hetzner and Cloudflare, plus the desktop, the Deck, the MacBook and the Mac mini.

## Language

**caboodle**:
The repo that configures every machine Shane runs. It deploys services but doesn't own them.
_Avoid_: homelab

**Service**:
Something a server runs for Shane, like Pocket ID, Immich or the brain. It's hers, used by her and her other projects; caboodle only deploys it.

## Machines

**Host**:
A machine Nix configures as a member of the colmena hive: PVE, Cube, a guest, the desktop, the Deck or a Mac.
_Avoid_: node, hive node

**Server**:
A host that runs services: PVE, Cube, every guest, and the mini. All but PVE and Cube deploy when a pull request merges. The mini is a workstation too.

**Workstation**:
A host that carries Shane's own setup: home-manager, fish and fonts. The desktop, the MacBook and the mini.
_Avoid_: machine Shane sits at

**Guest**:
A host that runs in an Incus container on PVE or Cube.

**Device**:
Something on the LAN with a reserved address that isn't a host, like the gateway or a smart plug. Each one is listed in `modules/devices.nix`. PVE and Cube are listed there too, and their hosts read their address and MAC from it.

## Changes

**Derivation diff**:
The hosts whose built system differs between a pull request's base and its head. It's the list of what a merge would rebuild.
_Avoid_: host diff, affected hosts

## Pipeline

**Mirror**:
The cold copy of every GitHub repo kept at home as bare clones, for recovery only.
_Avoid_: forge, backup forge
