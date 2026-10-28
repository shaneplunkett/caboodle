# CI redesign

Working notes from the design conversation begun on 28 October 2026.
The design is open. These notes record agreed requirements and questions
as the conversation progresses.

The interview is paused for external research at Shane's request. Examine
StepBro's own setup and Colmena work, the Nix evaluation GitHub tooling
she recalls from Determinate Systems, and established Nix CI systems before
asking her to choose implementation mechanisms. Full reuse of evaluated
results across comparison, build and deployment remains undecided.

The [external research](../research/2026-10-28-nix-ci-patterns.md) is now
recorded with source dates, verdicts and remaining gaps. It supports testing
bounded nix-eval-jobs evaluation or explicit Colmena batches before changing
the hive's configuration model. StepBro's Atelier retains repeated
attribute evaluations and Colmena deployment; Hestia and Hydra demonstrate
evaluated-derivation reuse. Both approaches have precedent.

The proposed next step is a comparison on one frozen caboodle revision,
checking identical complete derivation mappings and measuring memory,
CPU and elapsed time. Keep the existing deployment interface while testing
those options. This is a research recommendation, not a selected
implementation. No benchmarks have run. The research has not established
that the current cross-host configuration needs to change.

## Why revisit it

Caboodle's derivation diff gives Shane and coding agents a concrete view
of which hosts a change affects before deployment. Shane wants to keep
that visibility as the hive grows, without the increasing CPU and memory
cost making ordinary changes impractical.

The builder incident on 28 October exposed the current cost. A measured
full-hive evaluation peaked at 14.2 GB. Two PRs each evaluating base and
head concurrently exhausted the builder. Serialising those pairs with
a lock helped, but did not address the cost of evaluating a larger hive.

## Agreed starting points

- Reconsider CI end to end, including its relationship to deployment.
- Preserve an exact pre-deployment change preview. Its comparison point
  and the guarantees it provides still need defining.
- Examine how hosts share information as well as how CI runs evaluations.
- Preserve automatic cross-host configuration, including workstation SSH
  configuration generated from the hosts. Changing evaluation boundaries
  must not require Shane to maintain duplicate host lists or wiring by
  hand. An explicit shared-data boundary is a candidate to investigate,
  not an accepted restriction on access to host configuration.
- Design for Incus. Shane intends Cube to follow PVE onto Incus.
- Fit within the existing physical machines. Additional hardware or paid
  compute capacity is not an option. Resource allocation and scheduling
  within the existing machines can change. The design must address both
  the cost of an individual evaluation as the hive grows and concurrent
  demand; queuing alone does not solve an oversized evaluation.
- Keep caboodle as a monorepo. Changes spanning hosts and infrastructure
  stay together in review. Configuration dependencies and evaluation
  boundaries within the repo remain open to redesign.
- Reopen the previous implementation choices rather than treating them as
  requirements for this design.
- The forge choice is open. Shane is not committed to Forgejo and has
  encountered tooling friction. Assess the human and agent workflows as
  part of choosing a forge. Carry forward the existing forge plan's
  requirements: reliable PR and check status for Shane and agents,
  cancellation distinguished from failure, and Linear and CodeRabbit
  integration.
- An externally hosted forge is acceptable to consider. GitHub is an
  explicit candidate, with evaluation, builds and deployment staying on
  existing machines. No forge has been selected. A small fixed forge
  subscription is acceptable to consider, with the actual total checked
  before choosing. No exact spending limit has been set. This does not
  reopen the constraint against additional build capacity.
- Merging is implicit deployment approval. Routine deployment follows
  merge without a separate approval step. The existing manual-switch
  boundary for selected hosts remains in place unless explicitly revisited.
- Before merge, the preview and checks must cover the result of combining
  the PR with the current target branch. If another PR merges first, the
  remaining PR's earlier checks are insufficient unless their results are
  shown to remain valid. How to reuse that evidence is still open.
- Keep the existing level of review detail as the baseline: the derivation
  diff, CI build results, Terraform plan and code diff. Shane considers an
  additional generated explanation of why each host changes unnecessary
  overhead. The host list flags unexpected scope: expecting one host to
  change and seeing five is a reason to investigate. Supporting evidence
  must remain available to inspect, without explaining every change up
  front. A richer narrative is not a requirement of this redesign.
- A partial deployment failure halts further rollout and reports which
  changes succeeded or failed. Successful changes remain in place, and
  recovery is a deliberate action. Automatic rollback is not the default.
- Deployment success includes activation and declared service health
  checks. Failed health checks halt the rollout. Start with meaningful
  checks for important dependencies such as DNS; a bespoke test suite for
  every service is not required. Exact checks and ordering remain open.
- CI jobs use fresh disposable environments. Temporary files, databases
  and stray processes must not survive into another job. Build outputs,
  caches and reusable evaluation results have explicitly managed lifetimes
  separate from the job environment. The isolation mechanism remains open.
- Scope credentials by repo and job purpose. Deployment credentials are
  available only to approved post-merge deployment jobs. Fetching private
  dependencies and planning Terraform changes receive the access they
  actually require; Terraform plan credentials and permissions still need
  investigating. General CI jobs do not inherit the deployment credential
  set.

## Existing plans to reconcile

[Ephemeral CI jobs on Proxmox](https://linear.app/metrokitten/project/ephemeral-ci-jobs-on-proxmox-4d5adbf3de4c)
proposes disposable job containers and a persistent builder and cache.
[SHA-187](https://linear.app/metrokitten/issue/SHA-187) is its initial
manual spike. [SHA-197](https://linear.app/metrokitten/issue/SHA-197)
adds per-repo CI secrets.

[Leaving Forgejo and splitting up builder](forge-and-builder.md)
also considers a forge migration, a separate Attic cache and replacing
builder. Forge selection is part of this redesign; those proposals remain
options to assess against the requirements we settle here.

[Terraform reads the hive directly](../adr/0001-terraform-reads-the-hive.md)
records why Nix owns host data and Terraform reads it without a generated
copy. Any change to that boundary must revisit the trade-off explicitly.

## Open questions

- How do we establish current merge evidence without repeating work whose
  results remain valid?
- What must the preview show, and what is it compared against?
- What must pass before merge, deployment and declaring a deployment
  successful?
- Which information must hosts share, and what does evaluating it cost?
- Which evaluation and build results can later jobs safely reuse?
- Where do jobs, evaluations, builds, secrets and cached results belong?
- How does work queue within the available resources as the hive grows?
- How do failure, recovery and migration work without depending on the
  component being changed?

## Findings from the current implementation

Read-only inspection covered caboodle at `daf93929`, shared workflows at
`v1.6.1`, and the Colmena source pinned in `flake.lock`. No new evaluation
or build measurements were taken.

The [build workflow](https://git.shaneplunkett.com/shane/workflows/src/tag/v1.6.1/.forgejo/workflows/build.yml)
compares top-level system derivation paths at the PR's merge base and head.
That identifies changed build recipes. It does not compare running hosts,
service restart effects, Terraform state or a hypothetical merge with newer
target-branch changes. Only host names pass to the build jobs, which
evaluate their flake attributes again.

Main builds root every host's result in the builder store. Deployment is a
separate push workflow, without a dependency on that build workflow.
Colmena receives the checkout and host selectors rather than the PR's
evaluated derivations. Terraform separately evaluates `.#network`.

Cross-host reads include routes, OIDC clients, monitoring settings and SSH
configuration. Glance also reads generated nginx and oauth2-proxy
configuration. No cross-host top-level system derivation read surfaced in
the repository search. Colmena supplies these reads through lazy host
configuration graphs, with checked and unchecked configuration views.
Their contribution to evaluation cost has not been measured.

The shared store and binary cache preserve build results, but the inspected
workflow has no explicit handoff of evaluated derivations. PR results are
unrooted and can be garbage-collected. Evaluation-cache behaviour and
per-host evaluation costs remain unmeasured.

Two documentation mismatches need resolving during the design. The
Terraform ADR describes a preliminary plan without refresh, while the
inspected workflows use path filters and the script runs a normal plan.
The builder doc also promises oomd preserves reachability, whereas the
28 October handoff records it failing to trigger.

## Evaluation options to measure

Source inspection on 28 October found mechanisms worth testing before
restricting cross-host configuration. No profiling experiments have run.

The [pinned Colmena evaluator](https://github.com/stepbrobd/colmena/blob/eee6f1800c4b9b680c925be75da82f467ab6c1b6/src/nix/hive/eval.nix)
exposes `evalSelectedDrvPaths`, retaining checked configurations and access
to other hosts through `nodes`. Separate processes or smaller batches may
reduce retained evaluation state. Colmena also has chunked deployment
evaluation, but its automatic memory estimate is not a measurement of
caboodle. The cost of one host and the cost of repeating shared work need
measuring.

[`nix-eval-jobs`](https://github.com/NixOS/nix-eval-jobs/blob/9f1553afabd95f9f59951f5c946e86005af7196a/README.md)
is another candidate. It supports worker and memory budgets and can recycle
workers, but an individual host can still exceed the budget. Worker memory
accounting does not cover the separate Nix daemon.

An explicit manifest could retain the exact host-to-derivation mapping for
an immutable evaluated revision and its evaluation provenance. Nix can
build those derivations directly without evaluating the flake again.
The manifest must cover the current target plus PR result; an unchanged
lockfile alone does not establish safe reuse. Derivation closures and built
outputs also need retention, since JSON paths alone are not GC roots.
See the [Nix installable reference](https://nix.dev/manual/nix/2.34/command-ref/new-cli/nix.html#store-path).

The pinned Colmena CLI has no discovered external-manifest input. Reusing
that manifest for deployment would require additional integration, including
targeting and deployment policy. Built-output reuse also does not replace
activation and health checks.

The flake evaluation cache and binary cache are distinct from an explicit
manifest. Neither establishes that the current full-manifest command avoids
module evaluation. Their actual benefit here remains unmeasured.

### Proposed first measurements

Use one frozen revision and compare fresh individual evaluations of dns1,
desktop and dashboard with a single evaluation of the same three hosts.
Require matching derivation paths and record peak memory, CPU and elapsed
time. These hosts sample a small server, workstation SSH generation and
Glance's reads of ingress configuration.

Then compare narrowly projected metadata through the checked and unchecked
configuration views, and one unchecked desktop evaluation. These are
diagnostic comparisons, not a proposal to remove module checks. Extend to
the full host set and test cache behaviour only when the first results
justify it.

Run experiments on the builder in a supervised quiet window. Set resource
and runtime budgets from fresh builder and PVE headroom, account for the
separate Nix daemon, and abort on resource pressure. Establish whether
import-from-derivation is required before allowing a probe to trigger
builds. The existing evaluation lock and `MemoryMax` alone do not guarantee
that an experiment cannot disrupt other work.

## Forge findings

Checked against official documentation on 28 October 2026. These findings
keep candidates open; they do not select a forge.

GitHub's ordinary PR workflows can test a synthetic merge of target and
PR. Strict required checks must also enforce freshness when the target
changes. This does not require GitHub's native merge queue, whose
eligibility is restricted by repository ownership, visibility and plan.
See [workflow events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows),
[branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches)
and [merge queues](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/configuring-pull-request-merges/managing-a-merge-queue).

The current GitHub mirror is a public personal repository,
`shaneplunkett/caboodle`, confirmed with `gh`. Public repositories have
branch protection on Free. Private personal repositories require Pro;
private organization repositories require Team or Enterprise. Other repos'
requirements and the total subscription cost still need checking.

GitHub currently documents self-hosted runner execution as free. The
previous per-minute charge proposal was postponed, not confirmed as
permanently cancelled. GitHub-hosted artifact storage has separate billing.
See [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
and the [updated announcement](https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/).

Ephemeral GitHub runners accept one job and deregister, but destroying their
environments is still our responsibility. They connect outbound. GitHub's
standalone Runner Scale Set Client provides polling and registration
building blocks for custom provisioning; it is not a finished Incus
launcher. See the [runner reference](https://docs.github.com/en/actions/reference/runners/self-hosted-runners).

Both [Linear](https://linear.app/docs/github) and
[CodeRabbit](https://docs.coderabbit.ai/platforms/github-com) document
GitHub integrations. Linear's documentation does not clearly establish
the personal-repository installation flow, so that remains to verify.
CodeRabbit integration support alone does not establish entitlement to
ongoing reviews; account plans and eligibility need checking separately.

Self-managed GitLab remains a candidate. Its native
[merged-results pipelines](https://docs.gitlab.com/ci/pipelines/merged_results_pipelines/)
and [merge trains](https://docs.gitlab.com/ci/pipelines/merge_trains/)
require Premium or Ultimate. Implementing equivalent current-target
validation on Free would be additional engineering work.
[Linear needs to reach GitLab's URL](https://linear.app/docs/gitlab).
CodeRabbit also supports self-managed GitLab, with an optional reverse
tunnel whose pricing was not established. GitLab's resource use would
come from the existing machines and needs workload-specific sizing.

Both forges expose cancellation separately from failure. That does not
prove every client presents status reliably; the actual human and agent
workflows need testing.
