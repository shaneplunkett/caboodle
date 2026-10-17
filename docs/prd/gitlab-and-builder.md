# Moving to GitLab and splitting up builder

Builder runs the CI jobs, is the binary cache, holds the keys to every host
and deploys itself, and those roles collide: the self-deploy deadlock, the
deploy-first ordering, and every job being able to read the fleet's SSH key
and Terraform tokens. The forge adds its own friction: stale PR status,
cancelled runs shown as failures, and no Linear or CodeRabbit. The
[GitLab spike](../research/2026-10-17-gitlab-spike.md) tested the
replacement. Each step builds its piece once, in its final home.

1. **Proxmox to Incus.** Finish [leaving Proxmox](leaving-proxmox.md):
   NixOS hypervisors deployed by hand, guests moved across, and the Incus
   provider in place of `pve-*.tf`. Forgejo and builder keep running as they
   are.
2. **Cache box.** Attic on Incus. Builder pushes to it from the start, so
   it's warm before the throwaway runners need it.
3. **GitLab on Incus.** Pocket ID sign-in, a tunnel locked to Linear's and
   CodeRabbit's IPs with split DNS in Blocky, Linear, CodeRabbit, Renovate,
   and a push mirror to GitHub. The smaller repos move. vex-code picks up
   T3's per-job CI checks
   ([pingdotgg/t3code#13434](https://github.com/pingdotgg/t3code/pull/13434))
   first.
4. **Builder's replacement, in GitLab CI.** Throwaway runners started by a
   launcher on Incus, builds pushed to the cache, colmena deploying from
   `main` with protected variables, and Terraform. caboodle moves and builder
   goes.
5. **Retire Forgejo.** Then the `pr` skill, `tea` to `glab`, AGENTS.md and
   the docs.
