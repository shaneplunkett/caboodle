# Incus

Runs Incus on a NixOS host, with a bridge onto the LAN and an LVM-thin pool
for the guests' disks. `virtualisation.incus.preseed` sets up the pool and
the `default` profile, so they come from Nix rather than `incus admin init`.

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

## TUN

The `default` profile hands every guest `/dev/net/tun`, so Tailscale runs in
kernel mode. It's the Incus version of `proxmox/90-homelab-tun.conf`.
