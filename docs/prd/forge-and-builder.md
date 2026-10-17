# Leaving Forgejo and splitting up builder

Builder runs the CI jobs, is the binary cache, holds the keys to every host
and deploys itself, and those roles collide: the self-deploy deadlock, the
deploy-first ordering, and every job being able to read the fleet's SSH key
and Terraform tokens. The forge adds its own friction: stale PR status,
cancelled runs shown as failures, and no Linear or CodeRabbit. Each step
builds its piece once, in its final home.

1. **Proxmox to Incus.** Finish [leaving Proxmox](leaving-proxmox.md):
   NixOS hypervisors deployed by hand, guests moved across, and the Incus
   provider in place of `pve-*.tf`. Forgejo and builder keep running as they
   are.
2. **Cache box.** Attic on Incus. Builder pushes to it from the start, so
   it's warm before the throwaway runners need it.
3. **The new forge.** Undecided, between two options:
   - Self-hosted GitLab on Incus, which the
     [spike](../research/2026-10-17-gitlab-spike.md) tested. It brings Pocket
     ID sign-in, a tunnel locked to Linear's and CodeRabbit's IPs, split DNS in
     Blocky, and a push mirror to GitHub. vex-code needs T3's per-job CI checks
     ([pingdotgg/t3code#13434](https://github.com/pingdotgg/t3code/pull/13434)).
     It means more upkeep, and the forge runs on the cluster it deploys.
   - GitHub with Pro, US$4 a month for protected branches and environment
     secrets on private repos. Forgejo pulls a mirror of every repo. Workflows
     keep the Actions syntax, nothing reaches into the network, and the forge
     doesn't live on the cluster it deploys. The self-hosted runner fee for
     private repos is postponed, not cancelled.

   Either way, Linear, CodeRabbit and Renovate move with it, and so do the
   smaller repos.
4. **Builder's replacement, in the new forge's CI.** Throwaway runners
   started by a launcher on Incus, builds pushed to the cache, colmena
   deploying from `main` with secrets only `main` can read, and Terraform.
   caboodle moves and builder goes.
5. **Retire Forgejo as the source of truth.** It stays as GitHub's mirror if
   that's the pick. Then the `pr` skill, `tea`, AGENTS.md and the docs.
