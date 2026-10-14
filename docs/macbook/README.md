# The MacBook

The MacBook is a node in the hive, evaluated with nix-darwin like the mini.
Every pull request builds it on the mini, but nothing deploys it. Shane
switches it by hand on the laptop.
[docs/workstation](../workstation/README.md) covers what it shares with the
mini and the desktop.

## Why it's never deployed on merge

It's a laptop. It's often asleep or off the LAN, so a deploy on merge would
mostly fail, and a switch landing mid-work would swap apps out from under
Shane. The build check still proves every merge builds for it.

For the same reason it has no `homelab.lanAddress`, and monitoring is off,
since a sleeping laptop would trip HostDown all day.

## Switching

Use the recipe in
[docs/workstation](../workstation/README.md#switching-a-mac) with
`-H macbook`, or `nrs` from the checkout. The hostname stays
`Shanes-MacBook-Pro` so the tailnet name doesn't change.

## Gotchas

- Spotlight's Command+Space (symbolic hotkey 64) is off so vicinae can have
  it.
