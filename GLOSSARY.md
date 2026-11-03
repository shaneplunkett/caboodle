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
A host that runs services: PVE, Cube, every guest, and the mini. The guests deploy when a merge lands on `main`, the desktop applies the mini and the runner, and PVE and Cube are switched by hand. The mini is a workstation too.

**Workstation**:
A host that carries Shane's own setup: home-manager, fish and fonts. The desktop, the MacBook and the mini.
_Avoid_: machine Shane sits at

**Guest**:
A host that runs in an Incus container on PVE or Cube.

**Runner**:
The guest that runs the deploy job when `main` moves, and nothing else. It builds every Linux host and applies the servers, and the desktop deploys it.
_Avoid_: builder, CI box

**Cache**:
The guest whose store the runner and the mini push built closures into, served read-only by Harmonia so every host pulls instead of building. A shelf, not a service: losing it costs a slow week.
_Avoid_: binary cache server, Attic

**Device**:
Something on the LAN with a reserved address that isn't a host, like the gateway or a smart plug. Each one is listed in `modules/devices.nix`. PVE and Cube are listed there too, and their hosts read their address and MAC from it.

## Pipeline

**Mirror**:
The cold copy of every GitHub repo kept at home as bare clones, for recovery only.
_Avoid_: forge, backup forge
