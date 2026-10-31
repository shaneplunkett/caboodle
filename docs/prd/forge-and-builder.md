# Moving back to GitHub

## Decision, 31 October 2026

Shane chose GitHub as the primary forge, with a mirror in the homelab.
Forgejo's integration and tooling friction has become too much upkeep.
The plan is to keep Forgejo as the pull mirror, with PRs and integrations
moving to GitHub. The [GitLab spike](../research/2026-10-17-gitlab-spike.md)
remains research into the alternative, not work left to do.

The choice is made; the migration has not happened. Until cutover, changes
still go through Forgejo and its runner.

## Where the earlier plan stands

- [Leaving Proxmox and Unraid](leaving-proxmox.md) is complete. PVE moved
  to NixOS and Incus on 27 October and Cube on 29 October. Incus is no
  longer a prerequisite to schedule.
- The [28 October CI fix](../adr/0002-evaluate-once-and-block-outdated-branches.md)
  kept Colmena and the current derivation diff. Evaluations share a lock,
  `main` caches its mapping, the runner has memory backstops, and outdated
  branches cannot merge. These are the starting point for the GitHub move.
- Forgejo remains primary and pushes to GitHub. The migration reverses
  that direction. The [forge doc](../pve/forge.md) describes its current
  operation.
- Builder still runs persistent jobs, serves its store through Harmonia,
  holds deployment and Terraform credentials, and deploys itself. The
  [builder doc](../pve/builder.md) covers the restart workaround and deploy
  ordering. They remain relevant until the runner changes.
- A separate Attic cache, disposable runners and replacing builder were
  proposed in the earlier plan. None is implemented in this repo. Their
  design and sequencing remain open; choosing GitHub does not settle them.

## Work before cutover

1. Inventory the repos, their GitHub destinations and visibility, open PRs,
   releases, LFS and packages. Include `shane/workflows` and the forge-hosted
   flake inputs. Check the account plans and permissions each repo needs;
   the earlier assumption that everything needs GitHub Pro was too broad.
   The [28 October findings](ci-redesign.md#forge-findings) are a dated
   starting point for those checks.
2. Prepare GitHub CI on the existing machines. Port the shared workflows
   and checkout action in `shane/workflows`, then their callers. Preserve
   the derivation diff, required checks against current `main`, Terraform
   plan comments, merge-triggered deployment and the manual-switch hosts.
   Decide how to isolate jobs and credentials before enabling the runner.
   The [CI requirements](ci-redesign.md#agreed-starting-points) cover the
   intended isolation; the current runner does not provide it.
3. Prepare the integrations and repository references. Move Renovate,
   weekly flake updates and the `ai-skills` dispatch and self-merge flow.
   Verify Linear, CodeRabbit and T3 against the destination repos. Update
   forge-hosted flake URLs and private dependency access deliberately, so a
   delayed mirror cannot hold back a build.
4. Reconcile the last changes on Forgejo, stop its pushes to GitHub, then
   make GitHub authoritative and enable the homelab pull mirrors. Retain
   the existing Forgejo history and backups until PRs, releases and other
   metadata have an agreed home. Verify refs and a clone from the local
   copy. Define how LFS, releases and packages are retained separately from
   the Git refs.
5. Switch repo remotes, branch protections, bot access, agent skills and
   instructions to GitHub. Disable the old CI and update automation for
   each migrated repo so one merge cannot deploy twice. Prove the path
   from a GitHub PR through checks, review, merge and deployment, and check
   that the homelab mirror catches up.

The runner and cache work can be staged around this move. Before retiring
builder, account for its cached outputs, evaluation mappings, Darwin build
handoff and deployment credentials. Moving the forge alone does not remove
those jobs or the runner's self-deploy problem.
