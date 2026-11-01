# The MacBook

The MacBook is a host in the hive, evaluated with nix-darwin like the mini,
but nothing deploys it. Shane switches it by hand on the laptop, and it
pulls what the mini has already built
([the store as the cache](../workstation/README.md#the-store-as-the-cache)).
[docs/workstation](../workstation/README.md) covers what it shares with the
mini and the desktop.

## Why it's never deployed on merge

It's a laptop. It's often asleep or off the LAN, so a deploy on merge would
mostly fail, and a switch landing mid-work would swap apps out from under
Shane.

For the same reason it has no `homelab.lanAddress`, and monitoring is off,
since Prometheus can't scrape a sleeping laptop.

## Switching

Use the recipe in
[docs/workstation](../workstation/README.md#switching-a-mac) with
`-H macbook`, or `nrs`. The hostname stays
`Shanes-MacBook-Pro` so the tailnet name doesn't change.

## Gotchas

- Spotlight's Command+Space (symbolic hotkey 64) is off so vicinae can have
  it.
