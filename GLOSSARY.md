# caboodle

Every machine Shane runs, configured from one repo: the Proxmox cluster, Hetzner and Cloudflare, plus the desktop, the MacBook and the Mac mini.

## Language

**caboodle**:
The repo that configures every machine Shane runs. It deploys services but doesn't own them.
_Avoid_: homelab

**Service**:
Something a server runs for Shane, like the forge, Pocket ID or Immich. It's hers, used by her and her other projects; caboodle only deploys it.

## Machines

**Host**:
A machine Nix configures as a member of the colmena hive: an LXC, a VM, the desktop or a Mac.
_Avoid_: node, hive node

**Server**:
A host that runs services and deploys when a pull request merges: every LXC and VM, plus the mini. The mini is a workstation too.

**Workstation**:
A host that carries Shane's own setup: home-manager, fish and fonts. The desktop, the MacBook and the mini.
_Avoid_: machine Shane sits at

**Proxmox node**:
One of the two physical Proxmox machines, PVE and Cube, that run the LXCs and VMs. It's a device, not a host.
_Avoid_: bare "node"

**Device**:
Something on the LAN with a reserved address that isn't a host, like the gateway, a Proxmox node or a smart plug. Each one is listed in `modules/devices.nix`.

## Changes

**Derivation diff**:
The hosts whose built system differs between a pull request's base and its head. It's the list of what a merge would rebuild.
_Avoid_: host diff, affected hosts
