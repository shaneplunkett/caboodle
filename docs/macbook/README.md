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

`macbook-air` is Shane's work laptop. Work manages it with a device profile,
so it runs the MacBook's setup without the personal parts. Everything here
applies to it, with `-H macbook-air`. Its hostname is `Shanes-MacBook-Air`,
and no secret is encrypted to it, so its first switch doesn't need a host key.

`hosts/macbook-air.nix` lists what it leaves out:

- The two `personal.nix` modules, one in `modules/workstation/darwin/laptop`
  and one in `home/shane/modules/common`. Anything the MacBook should have
  and a work laptop shouldn't goes in one of those.
- Work chats. `vex sync-cc` and `vex sync-codex` also read `~/.claude-work`
  and `~/.codex-work` unless told otherwise, so the Air's sync agents name
  the personal folders and work sessions stay on the laptop.

Git differs too. vex-code can't juggle two GitHub accounts, so the
Air only uses the work one, and personal repos get worked on from the other
machines through vex-code. The `work` module in `nix-config-private` sets its
identity, signing key and GitHub SSH key, and globally ignores the Nix files
work repos can't carry. Only this host imports it. The inputs token is separate
from any of that, so `nrs` keeps working.

## Gotchas

- Spotlight's Command+Space (symbolic hotkey 64) is off so vicinae can have
  it. A change to these shortcuts waits for the next login, since macOS only
  rereads them then or when `activateSettings -u` runs.
- OmniWM's command palette has no shortcut, since vicinae is the launcher
  and its default, Control+Option+Space, is macOS's "Select next source in
  Input menu".
- OmniWM keeps a settings file it can't parse as `settings.toml.corrupt`
  beside the live one and warns about it in Health until the file is gone.
  The warning says nothing about the live file, so check the dates before
  chasing it.
- Slack is `pkgs/slack-themed`, patched and re-signed ad hoc, so it loses
  Slack's own entitlements. Sign in through the browser, since passkeys in
  the app and `slack.com` links opening it depend on those entitlements. The
  version moves with nixpkgs, not Slack's updater.
