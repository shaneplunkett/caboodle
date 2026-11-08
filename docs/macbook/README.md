# The MacBook

The MacBook is a host in the hive, evaluated with nix-darwin like the mini,
but nothing deploys it. Shane switches it by hand on the laptop, and it
pulls from the [cache](../pve/cache.md), where the
[mini's runner](../mini/README.md#the-runner) pushes its closure on every merge.
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

## The MacBook Air

`macbook-air` is Shane's work laptop, and it runs the same setup as the
MacBook, because work doesn't manage its Macs. Everything here applies to it,
with `-H macbook-air`. Its hostname is `Shanes-MacBook-Air`, and no secret is
encrypted to it, so its first switch doesn't need a host key.

## Gotchas

- Spotlight's Command+Space (symbolic hotkey 64) is off so vicinae can have
  it.
- Slack is `pkgs/slack-themed`, patched and re-signed ad hoc, so it loses
  Slack's own entitlements. Sign in through the browser, since passkeys in
  the app and `slack.com` links opening it depend on those entitlements. The
  version moves with nixpkgs, not Slack's updater.
