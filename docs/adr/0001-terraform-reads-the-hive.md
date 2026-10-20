# Terraform reads the hive directly

Terraform gets every host's address, the devices and the port forwards by
evaluating `.#network` from the flake, rather than from a generated file
committed next to it. Nix owns the hosts and Terraform owns the resources,
and nothing is copied between them, so there's no third copy to drift.

The cost is that Terraform's inputs live outside `terraform/`, so the usual
path filter ("run Terraform if its folder changed") can't tell whether it
needs to run: it fires on hive edits Terraform never reads and misses ones
it does. Deploys and pull requests ask Terraform instead, with a plan
against state that skips the refresh. It runs the real plan if that finds
changes or fails, and skips Terraform if not.

## Considered options

- **A generated `terraform/network.json` with a staleness check in CI.**
  This keeps the standard path filter honest and shows address changes in
  the diff, but it's a second copy of the hive that someone has to remember
  to regenerate.
- **Path filters on `flake.nix` too.** This is what ran before. It started
  Terraform for edits it can't see, so an unrelated provider outage blocked
  them, and it missed address changes in `modules/devices.nix`.
