# Incus

Runs Incus on a NixOS host, with a bridge onto the LAN and an LVM-thin pool
for the guests' disks. `virtualisation.incus.preseed` sets up the pool and
the `default` profile, so they come from Nix rather than `incus admin init`.

## Storage

The host's disko makes an empty LVM volume group called `incus`, and the
pool's `source` names that group rather than a partition. Once it creates a
pool, Incus records its source as the group's name, so a preseed naming the
partition fails on every run after the first ("Pool source cannot be
changed"), and never reaches the profile.

## Terraform's access

Terraform talks to Incus over HTTPS on port 8443 with a client certificate.
`terraform.crt` is that certificate, and its key is the runner's
`terraform-incus-key` secret. `incus-trust-terraform` adds the certificate
to the trust store if it isn't there.

The preseed has a `certificates` section, but it isn't used here. Incus
creates each certificate on every run and fails once it exists, so the
preseed unit would fail on every boot after the first.

To replace the pair, from `modules/agenix`:

```sh
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:secp384r1 -nodes \
  -days 3650 -subj /CN=terraform -keyout /dev/stdout \
  -out ../services/incus/terraform.crt \
  | RULES=./agenix-rules.nix nix develop ../.. -c agenix -e terraform-incus-key.age
```

Then remove the old certificate with `incus config trust remove`, since the
unit only adds.

## Guests

A guest is a hive node with `homelab.guest` set, which names its Incus host
and its size. `network.guests` exports them, and `terraform/incus.tf`
creates each container from the base image with its UniFi reservation. The
container's name is the node's name, and NixOS leaves the hostname to Incus.

The base image is `nixosConfigurations.incus-base`, built on the runner by
`scripts/incus-image.sh`. A guest only uses it once, when it's created, so
Terraform ignores newer builds. To refresh it, run
`terraform apply -replace='incus_image.nixos["<host>"]'`.

`running = false` creates the container without starting it. Use it when a
guest takes over another's MAC, so the two never share the LAN.

## VLANs

`br0` filters by VLAN, like a VLAN-aware bridge on Proxmox. The uplink
carries VLAN 1 untagged, which is the LAN the host and most guests sit on,
and every other VLAN tagged. A guest joins one with `vlan` on its NIC, so a
new VLAN needs no change on the host.

networkd removes any VLAN on a port that its `.network` file doesn't list, so
only the uplink has `bridgeVLANs`. The guests' ports are Incus's to manage,
and no `.network` file matches them.

## TUN

The `default` profile hands every guest `/dev/net/tun`, so Tailscale runs in
kernel mode. It's the Incus version of `proxmox/90-homelab-tun.conf`.
