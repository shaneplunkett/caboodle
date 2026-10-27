# Proxmox nodes

Config that lives on Cube itself, where Nix can't reach. Cube is the only
Proxmox node left, a cluster of one. PVE is a NixOS host now, so none of
this applies to it ([docs/pve](../docs/pve/README.md)).

## TUN for containers

`90-homelab-tun.conf` gives every container on Cube `/dev/net/tun`, so
Tailscale can run in kernel mode. Every container includes
`common.conf.d` through `common.conf`, so there's nothing per-container.

Install it on Cube, and again after rebuilding it:

```sh
scp proxmox/90-homelab-tun.conf root@<cube>:/usr/share/lxc/config/common.conf.d/
```

Incus guests get TUN from the `default` profile instead
([incus](../modules/services/incus/README.md#tun)).

Running containers only pick it up when they restart.

Why it's done this way:

- Proxmox only lets `root@pam` set device passthrough. API tokens are refused,
  even root's, so Terraform's token can't add `dev0` and CI never could.
- A container with both `dev0: /dev/net/tun` and this drop-in fails to start.
  PVE's autodev hook creates the device for `dev0` and dies when the bind
  mount already made it. Don't add `dev0` for TUN anywhere.
- No package owns the file, so Proxmox upgrades leave it alone.

## Node exporter

A rebuilt Cube needs `node-exporter.sh` run again:
`terraform apply -replace='terraform_data.node_exporter["cube"]'`.

- **Containers see the host's sensors.** Every container's node exporter
  reports the hypervisor's temperatures too, so the hardware rules only look
  at the hypervisors themselves.

## Cube's second NVMe

Cube's second NVMe is the `nvme-thin` storage, a thin pool `nvme` in volume
group `nvme`. Proxmox has to set up the disk before Terraform can use it,
and the provider can't do that. To make it again:

```sh
dev=$(readlink -f /dev/disk/by-id/nvme-Samsung_SSD_970_EVO_Plus_1TB_<serial>)
sudo pvesh set /nodes/cube/disks/wipedisk --disk "$dev"
sudo pvesh create /nodes/cube/disks/lvmthin --device "$dev" --name nvme --add_storage 0
```

- **Proxmox hides disks that have anything on them.** The GUI's LVM-Thin
  dialog only lists empty disks, so a leftover filesystem makes the disk
  look missing. Wipe it first.
- **Go by serial, not `nvme0`/`nvme1`.** Those names can swap between boots,
  and the other NVMe is the boot disk.

## Notifications to Discord

Proxmox sends its notifications, like the daily "packages available" and
backup results, to the homelab alerts channel through a webhook target named
`discord`, and the `to-discord` matcher routes everything to it. They're
cluster-wide, which is only Cube now. The webhook's ID and token are a
Proxmox secret, and the body only carries the title and severity, because a
full package list goes past Discord's message limit.

To make them again, from `modules/agenix` in this repo:

```sh
url=$(agenix -d discord-webhook.age | cut -d= -f2-)
body=$(printf '%s' '{"username":"Proxmox","embeds":[{"title":{{ json title }},"description":{{ json severity }}}]}' | base64 -w0)
printf '%s\n' "${url#*/webhooks/}" | ssh shane@<cube> "sudo bash -c 'read -r token
pvesh create /cluster/notifications/endpoints/webhook --name discord --method post \
  --url \"https://discord.com/api/webhooks/{{ secrets.webhook }}\" \
  --header \"name=Content-Type,value=\$(printf %s application/json | base64 -w0)\" \
  --body $body --secret \"name=webhook,value=\$(printf %s \"\$token\" | base64 -w0)\"
pvesh create /cluster/notifications/matchers --name to-discord --target discord'"
unset url
```

- **The URL has to look like a URL.** Proxmox rejects one that's only a
  template, so the public part stays in the URL and only the ID and token
  are a secret.
- **Matchers and targets share names**, so the matcher can't also be called
  `discord`.

## Upgrading Cube

Proxmox's daily check posts to Discord when packages are waiting. Cube's LXCs,
monitoring and dns2 among them, are down while it reboots. PVE has no apt.
It gets the weekly flake update when it's switched by hand.

```sh
ssh shane@<cube> 'sudo apt-get -s full-upgrade | grep -E "^Remv|upgraded"'
ssh shane@<cube> 'sudo systemd-run --unit=pve-upgrade --collect --setenv=DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confold full-upgrade'
ssh shane@<cube> 'sudo journalctl -fu pve-upgrade'
ssh shane@<cube> 'sudo systemctl reboot'
```

The dry run is there to catch anything being removed, which a normal upgrade
never does. Running the upgrade as its own unit means a dropped SSH session
can't interrupt dpkg. The old kernel stays installed, so if a new one
misbehaves, `proxmox-boot-tool kernel pin <version>` and a reboot goes back.

## The builder's key

The builder's SSH key is in `shane`'s `authorized_keys` on Cube, so
Terraform on the builder can run `pct` for container devices and bind mounts.
Add it again after rebuilding Cube:

```sh
ssh root@builder ssh-keygen -y -f /run/agenix/builder-ssh-key | ssh shane@<cube> 'cat >> ~/.ssh/authorized_keys'
```
