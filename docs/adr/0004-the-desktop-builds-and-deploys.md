# The desktop builds and deploys, and CI only checks

Shane's desktop evaluates, builds and deploys the hive, and CI runs
`scripts/check.sh` and nothing else. October's pipeline was built so that
twenty-odd changes a day could each be built, diffed and deployed without
touching the desktop: a builder guest, a cache guest, a 666-line hosts
workflow evaluating every host on its own hosted runner against its merge
base, and a deploy that needed the deploy keys and Terraform tokens in CI.
Reviewing its output had become a job, and the rate of change it served was
the problem, not the thing to optimise for. A homelab with one operator
deploys from her machine.

The desktop has 32 GB, and the whole hive evaluates in about 15. One
evaluation fits; two at once took the box down, which is where the "never
build here" rule came from. `scripts/quietly.sh` fixes that directly: one
build at a time, at idle CPU and I/O priority, capped at 20 GB, so a build
never gets in the way of a game. `scripts/deploy.sh` applies a host or every
server, dns2 after dns1. `scripts/terraform.sh` reads its tokens from the
agenix secrets Shane's key decrypts, so no credential lives in a CI secret
store. The mini builds on itself, since the desktop can't build darwin.
Each architecture's builder serves its store to its sibling: the desktop to
the Deck, the mini to the MacBook.

The costs: nothing deploys unless the desktop is on and someone runs the
script, so a merge changes nothing until then; no derivation diff on a pull
request, so what a change does to a server is seen at apply time; and a
flake bump lands unbuilt, to be found when it's deployed. All three are
accepted. This supersedes 0002, which kept the builder and put its
evaluations behind one lock, and 0003, which moved CI to GitHub-hosted
runners evaluating and building each host alone. Both were deleted once
this landed; `git log --diff-filter=D -- docs/adr` finds them.

## Considered options

- **GitHub-hosted runners building per host** (0003). Fits a 16 GB runner
  only by evaluating each host alone, which is the matrix, the baseline
  mapping and the attempt markers. The size came from the constraint, not
  the job.
- **Keeping the builder** (0002). One persistent box with every key, and the
  desktop still barred from building, for a pipeline nobody wanted to read.
- **Pulling the workstations out of the hive** so a servers-only hive fits a
  hosted runner. A large refactor to keep a pipeline that had already proved
  unnecessary.
