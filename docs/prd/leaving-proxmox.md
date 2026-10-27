# Leaving Proxmox and Unraid

## Problem

Proxmox is the one part of caboodle that Nix can't reach. Its config lives on
the nodes: the TUN drop-in copied over by hand, node exporter piped in over
SSH, storage and bridges clicked together in the UI. Device passthrough only
works as `root@pam`, so Terraform's token can't set it. A dead node means
remembering what was clicked.

Unraid runs as a VM on PVE, and the only part of it in use is the NAS. It
holds 4GB of RAM, needs two PCI devices and the USB stick passed through, and
its config lives in its own UI.

## Decision

- PVE and Cube become NixOS hosts running Incus. Each host's config is in the
  hive, like every other machine.
- Unraid goes. A `nas` module mounts the same drives, pools them with
  mergerfs, and adds SnapRAID parity once there's a drive for it.
- Guests stay LXC containers, and each stays its own colmena node.

## Why Incus

NixOS can run containers itself (`containers.<name>`, or microvm.nix for
VMs). Those guests build into the host's config and share its store, so
deploying Plex would mean switching Cube. That breaks the deploy model the
repo is built on, where guests deploy on merge and the hypervisor changes
rarely and by hand.

Incus guests are separate machines with their own store. colmena deploys them
the same way it deploys LXCs today. Incus also brings snapshots, `incus move`
between hosts, and VMs for anything that isn't NixOS.

## How the pieces split

| Layer | Where it lives |
|---|---|
| Running Incus | NixOS options on each host (`virtualisation.incus.*`) |
| Storage pools, networks, profiles | `virtualisation.incus.preseed` on each host |
| Guests | Declared in the hive, applied by one Terraform `for_each` with the Incus provider |
| Guest images | Built by the flake, imported with `incus_image` |

Preseed creates and updates but never deletes, which is fine for host
plumbing that rarely changes and the wrong fit for guests. Terraform gives
guests plan comments, deletes and drift detection, and the per-host
`pve-*.tf` and `cube-*.tf` files go away.

Two Incus hosts don't make a good cluster, since Raft needs three voters for
quorum. Run them as standalone servers and add each as a remote.

## Storage

Unraid's array disks are plain XFS, one partition each, and the cache is a
btrfs NVMe. Nothing is encrypted and there's no parity drive yet, so the
drives mount on NixOS as they are. No copying, no reformatting.

- `/mnt/user` pools the cache and every disk with `category.create=ff`, so
  new files land on the NVMe. Every share and export points here.
- `/mnt/user0` pools the disks alone with `mfs`. The mover writes here.
- The mover runs nightly and moves anything under `Media` and `Programs`
  untouched for a day off the cache. `appdata` stays on the cache, like
  Unraid's cache-only setting.
- SnapRAID parity is a snapshot, updated by `snapraid sync` on a timer, not
  live like Unraid's. That suits a media library. Its parity drive must be at
  least as big as the biggest data drive, with some room spare. A sync holds
  about 1 GiB of RAM per 16 TB of data while it runs and nothing after.

The names match Unraid's on purpose, so paths in exports and arr settings
don't change.

## Phases

1. **NAS VM replaces Unraid on Proxmox.** A NixOS VM takes Unraid's MAC, so
   it gets Unraid's address, and takes over the HBA and NVMe. It exports the
   same NFS and SMB shares with the same options, so Proxmox, Plex, arr and
   the desktop don't notice the swap. It starts read-only. Rolling back means
   stopping it and starting Unraid.
2. **PVE becomes NixOS and Incus.** PVE's config imports the same `nas`
   module, the drives attach to the host directly, and the VM goes. Guests on
   PVE get the pool as a bind mount instead of NFS.
3. **Cube follows.** Its guests reach the pool over NFS from PVE.

Splitting it this way means storage is proven before the hypervisor changes,
and nothing gets debugged twice at once.

## Phase 1 checks

1. Stop Unraid, start the NAS VM, and check every drive and both pools
   mount. The cache doesn't need emptying first, since `/mnt/user` includes
   it.
2. Clear the stale handles, then check Plex plays and arr sees the library.
3. Turn off `homelab.nas.readOnly` and deploy. A download lands on the NVMe,
   arr hardlinks it into the library, and the mover moves both copies as one
   file.
4. Leave it running for a week or two, then delete the Unraid VM.

## Gotchas

- **NFS over mergerfs** needs `never-forget-nodes=true`,
  `inodecalc=path-hash` and a fixed `fsid` per export, or clients get stale
  handles.
- **The exports must wait for the pool.** If NFS starts before mergerfs
  mounts, it exports the empty directory underneath and clients write onto
  the root disk. `nfs-server` and `samba-smbd` require `/mnt/user`.
- **Everything is owned by 99:100.** NFS squashes every client to it and
  Samba forces it, as Unraid did. The `nas` user holds uid 99.
- **The mover keeps hardlinks** by handing rsync the whole file list with
  `-H`. Moving files one at a time would split each torrent from its library
  copy and use the space twice.
- **Only one of Unraid and the NAS VM may start on boot.** Both claim the
  same devices and MAC. Unraid stays in Terraform, stopped and off at boot,
  so rolling back is flipping those two settings.
- **Clients keep stale handles after a swap.** Lazily unmount the shares on
  each Proxmox node (`umount -l /mnt/pve/unraid-*`, and Proxmox mounts them
  again), restart the containers that bind them, and do the same for the
  desktop's SMB mounts.
- **The mover skips SQLite's `-wal`, `-shm` and `-journal` files.**
  Calibre-Web-Automated keeps its database in `Media/library`, open all the
  time. Unraid's mover skipped open files, so its sidecars sat on the cache
  for days. Moving them under an open database can corrupt it.
- **A pool with a missing disk doesn't mount**, which matches Unraid refusing
  to start its array. arr would otherwise see files vanish.

## Left to decide

- LVM-thin or btrfs for the Incus storage pool on each host.
- Retiring Unraid's UI, its Glance widget, its Pocket ID client and its
  ingress route.
- Whether the desktop moves from SMB to NFS.
- Whether the mover should skip every file a client still has open. NFS
  clients' open files aren't visible on the server, so this needs more than
  `fuser`.
