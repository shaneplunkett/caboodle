# Terraform reads the hive directly

Terraform gets every host's address, the devices and the port forwards by
evaluating `.#network` from the flake, rather than from a generated file
committed next to it. Nix owns the hosts and Terraform owns the resources,
and nothing is copied between them, so there's no third copy to drift.

The cost is that Terraform's inputs live outside `terraform/`, so a path
filter on that folder alone can't tell whether it needs to run. This record
first chose a plan against state that skips the refresh as the gate, but
that was never built. CI path-filters instead, on `terraform/`, `flake.nix`,
`modules/devices.nix` and `scripts/terraform.sh`. That runs Terraform for
some hive edits it never reads, but misses none it does.

## Considered options

- **A generated `terraform/network.json` with a staleness check in CI.**
  This keeps the standard path filter honest and shows address changes in
  the diff, but it's a second copy of the hive that someone has to remember
  to regenerate.
- **Path filters on `flake.nix` too.** This is what runs, with
  `modules/devices.nix` added on 24 Oct 2026 after a devices-only change got
  no plan. It still starts Terraform for flake edits it can't see, so an
  unrelated provider outage can block them.
