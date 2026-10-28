# Evaluate once, and block outdated branches

A pull request's derivation diff evaluates its head once and compares it
with the mapping `main` cached for the merge base, and `main` refuses to
merge a branch that's behind it. Every full evaluation of the hive on the
builder takes the same lock, and the runner has a memory cap, with oomd as
a second line for thrashing below it. Colmena, Forgejo, the monorepo and
what the diff compares all stay as they were. Two pull requests evaluating
base and head side by side took the builder down twice on 28 October, and
this fixes that without a redesign.

The cost is a rebuild after every merge. Each open pull request goes stale
when another lands, and has to be updated and checked again before it can
merge, so a Renovate morning queues. The `ai-skills` self-merge can strand:
if anything merges while its pull request is building, Forgejo keeps the
scheduled merge but won't run it on a behind branch, and nothing refreshes
the branch until the next `ai-skills` push or an Update Branch by hand.
Renovate's pull requests recover on their own, since it rebases them
daily. Each evaluation still covers the whole hive, so a bigger hive still
costs more per run. The [CI redesign notes](../prd/ci-redesign.md) say
when to reopen this.

## Considered options

- **The full redesign now: nix-eval-jobs, ephemeral runners, maybe a new
  forge.** It addresses the cost of one evaluation as the hive grows, not
  only how many run at once, but nothing was measured yet and it changes
  most of CI in one go. A single evaluation is 14 GB on a 48 GB box, so
  the size of one isn't the problem today.
- **Renovate's `rebaseWhen: conflicted`, to stop the rebase bursts.**
  Renovate rebasing every open pull request at once set off both wedges.
  But Forgejo's automerge won't merge a behind branch under the new rule,
  so Renovate has to rebase its own to land them.
- **Evaluate a synthetic merge of the pull request and `main`.** That's
  what GitHub's pull request checks do. It's no fresher than requiring an
  up-to-date branch, since the merge result goes stale the moment `main`
  moves too, and it needs a merge commit made in the job.
