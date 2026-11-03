# Runner

Incus guest on PVE that runs GitHub Actions jobs for caboodle, one at a time.
The service is `modules/services/github-runner`, and
[ADR 0005](../adr/0005-merges-deploy-from-a-runner-at-home.md) has the why.
`.github/workflows/runner-smoke.yml` is the only workflow on it so far. Run
workflow on its Actions page prints the hostname and the job's memory cap,
then builds `hello` through `scripts/quietly.sh`.

## The three rules

- **One job.** One registration takes one job, so a second dispatch waits in
  GitHub's queue. Checks and Renovate stay on GitHub's runners.
- **Skinny roles.** It holds what the deploy needs and nothing more, from
  agenix. It serves nothing: no `sshServe`, no signing key, no routes. It isn't
  in the `deploy` tag, so `scripts/deploy.sh runner` from the desktop is the
  only thing that deploys it.
- **Nukeable.** Nothing but the next deploy depends on it. See
  [Nuking it](#nuking-it).

## Registration

The runner registers with the GitHub App, not a personal token. Before
`github-runner-homelab.service` starts, `github-runner-registration.service`
fills `/run/github-runner-registration/token`, a root-only file on tmpfs:

1. A runner with credentials in `/var/lib/github-runner/homelab` gets its
   module's own `.current-token` copied back. No call to GitHub.
2. A runner without them signs a JWT with the App's key, mints an installation
   token narrowed to caboodle and `administration: write`, and asks for a
   registration token.

The copy in step 1 exists because the NixOS module wipes the runner's state and
registers again whenever the token file differs from `.current-token`. Minting
on every start would register on every start. The oneshot is its own unit so
that `LoadCredential` never hands the App's key to the runner's service, where
every job could read it.

**The App needs Administration write.** GitHub lists
`POST /repos/{owner}/{repo}/actions/runners/registration-token` under
"Repository permissions for Administration" in
[Permissions required for GitHub Apps](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps).
Without it the token request fails with a 422, "The permissions requested are
not granted to this installation", and the runner never starts. In the App's
settings on GitHub, set Repository permissions > Administration to Read and
write, then accept the new permission on the installation under Settings >
Applications.

That grant covers every repo the App is installed on, and any token minted
without narrowing inherits it, so Renovate's token and the mirror's can now
change repo settings or delete a repo. Anyone with the private key can too.

## Fencing

Three layers keep a job off its neighbours. `homelab.guest.background` is the
outer one.

- **CPU.** `limits.cpu.allowance = 11%` with `limits.cpu.priority = 0` gives a
  `cpu.weight` of 1 against every other guest's 100. Priority alone only
  reaches 90, since Incus takes it as a tiebreak. 10% would come to 0, which
  the kernel refuses. The allowance is soft, so an idle PVE gives the runner
  all 8 cores.
- **Disk.** `limits.disk.priority = 0` gives an `io.weight` of 10. This does
  nothing yet, see below.
- **Memory.** `github-runner-homelab.service` and `nix-daemon.service` share
  `runner.slice`, whose `MemoryMax` sits a few GB under the guest's limit, and
  PVE has no swap to thrash. One slice rather than a cap on each service,
  because evaluation runs in the job's process and builds run in the daemon,
  and two separate caps would add up to more than the guest has. The cap is on
  the slice rather than in `scripts/quietly.sh`, so everything a job spawns is
  under it, wrapper or no wrapper. `OOMPolicy=continue` means the kernel kills
  the biggest process and the listener survives to report a red job. The
  daemon's `max-jobs` and `cores` are pinned low so a cold hive build can't
  run eight compilers at once into that cap.

`scripts/quietly.sh` still gives a job its lock and `nice`. Its
`systemd-run --user` scope can't work here, since the service has no user
manager, so it falls back as it does on a Mac. Getting one would mean lingering
and opening `/run/user` in the unit's sandbox, for a cap that a bare `nix eval`
in a job would walk around.

Inside the guest, the slice's `CPUWeight=idle` and `IOWeight=1` let SSH and
Tailscale win, and the daemon runs at idle CPU and I/O priority.

**The disk priority has no effect until PVE enforces `io.weight`.** Only the
iocost controller reads it. PVE's NVMes use the `none` scheduler and
`/sys/fs/cgroup/io.cost.qos` is empty, so a job's disk I/O competes evenly with
every guest on the pool. Writing `<major>:<minor> enable=1` for `nvme1n1` into
that file at boot turns iocost on, for every guest on that disk.

### Garbage collection

`nh clean` already runs weekly on every NixOS host through `modules/nixos.nix`,
and NixOS warns against `nix.gc.automatic` beside it. `min-free` and `max-free`
in the module start a collection well before the disk alert fires and stop it
once there's room for a workstation closure, which is the biggest thing a
build leaves behind. The disk is thin, so it only takes what it uses from
PVE's pool.

### Proving the fence

Run the smoke workflow with `runaway` ticked. The last step should fail with
exit 137, and the runner should stay online for the next job.
For the run's window, read these in Grafana:

- `rate(incus_cpu_seconds_total{instance=~"192.168.1.169.*"}[1m])`: the other
  guests' CPU should keep its usual shape.
- `incus_memory_OOM_kills_total`: only `runner` should move.
- `rate(node_pressure_memory_stalled_seconds_total{host="pve"}[1m])`: PVE
  itself should stay near zero.

## Nuking it

The state is disposable and the identity isn't. A new container has a new SSH
host key, which can't decrypt the guest's agenix secrets, so
`runner-ssh-host-key.age` holds the key, encrypted to Shane alone. The hive
deploys to the guest's LAN address, so a rebuilt guest doesn't need Tailscale
first.

On PVE, `incus delete --force runner`. Then from the repo on the desktop:

```sh
scripts/terraform.sh apply
(cd modules/agenix && agenix -d runner-ssh-host-key.age) \
  | ssh root@pve 'incus exec runner -- sh -c "umask 077 \
      && cat > /etc/ssh/ssh_host_ed25519_key \
      && ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key > /etc/ssh/ssh_host_ed25519_key.pub \
      && systemctl restart sshd"'
scripts/deploy.sh runner
```

The key goes in through PVE and `incus exec`, not SSH, because the new guest
answers with a freshly generated key that the desktop's `known_hosts` would
refuse. Writing the file isn't enough on its own: sshd keeps serving the key
it loaded at boot until it restarts, and the `.pub` beside it has to match.
Terraform keeps the MAC and the UniFi reservation, and its plan should only
touch `runner`. The runner mints a token, and `replace` takes over the old
registration's name. In the Tailscale console, delete the old node and rename
`runner-1`.

## Gotchas

- **A registered runner keeps an old token on disk.** The module stores
  `.current-token` in its state directory, mode 600. A registration token
  lasts an hour, so it's dead long before it could matter, but the file only
  stays RAM-only until the module copies it.
- **Changing the registration fails once, then heals.** A new label, name or URL
  makes the module wipe the state and register with the old token, which GitHub
  refuses. `Restart=on-failure` starts it again 30 seconds later, the oneshot
  finds no credentials and mints a new one. A switch can report the unit as
  failed in between.
- **A failed mint doesn't retry.** If GitHub or the permission is missing, the
  oneshot fails and the runner stays down, on purpose, so a switch can't hang
  waiting on GitHub. `systemctl start github-runner-homelab` tries again.
- **GitHub drops a runner offline for 14 days,** and credentials on disk won't
  bring it back. Stop the service, `rm -rf /var/lib/github-runner/homelab`, and
  start it.
- **The work directory is on disk,** at `/var/lib/github-runner-work`. The
  module's default is `/run`, which would count checkouts and Nix's fetcher
  cache against the memory cap. The module empties it on every start, and it's
  also the job's `HOME`.
