# The Mac mini and the homelab

> Superseded: the mini is a hive node now; see [docs/mini](../mini/README.md).
> The rest is kept as the reasoning that led there.

The mini runs real homelab work, but it lives outside the homelab's rules.
Its config is in nix-config, not this repo, and it skips most of what every
hive host gets for free. The transcription server
([transcription-server.md](transcription-server.md)) would be its first web
app for the house, so this needs settling before that gets built.

Shane and Vex noticed this in October 2026, while working out how the
transcription server would be reached. Nothing here is decided. It lists
what's different and the questions to answer.

## What it does

- It's the darwin remote builder for the forge runner
  (`modules/services/forgejo-runner/darwin-builder.nix`).
- It runs vex-code headless as a launchd agent.
- It runs the vex-sync daemons.

nix-config manages it with nix-darwin and home-manager. In this repo it's
only an entry in `modules/devices.nix`, which gives it a DHCP reservation
and nothing else.

## What it skips

Every hive host gets these from the colmena defaults. The mini has none of
them.

- **Monitoring.** There's no node exporter scrape, so no HostDown alert. If
  the mini dies, nothing says so.
- **Logs.** Alloy doesn't ship anything from it to Loki.
- **Backups.** It isn't in `backup_hosts` and has no restic job.
- **Tailscale.** It runs the Homebrew app, not a declared daemon, and it
  isn't tagged `tag:homelab`, so there's no TailscaleDown alert. Its
  Tailscale Serve config, which is how vex-code is reached, was set up by
  hand.
- **Routing.** Its apps are reached through Tailscale Serve on
  `*.ts.net` names, not `*.shaneplunkett.com` through ingress.
- **Sign-in.** Nothing on it goes through Pocket ID.
- **Deploys.** Merging here never touches it. It changes when someone runs a
  switch from nix-config.

## The firewall

nix-config turns on the macOS application firewall with stealth mode on
every Mac (`modules/darwin/base/settings.nix` in nix-config). It lets
signed apps take incoming connections and silently drops the rest. Anything
built by Nix is ad-hoc signed, so it gets dropped. With stealth mode the
client sees no refusal, just a connection that hangs until it times out.

This is why vex-code listens on loopback behind Tailscale Serve. Tailscale
is a signed app, so the firewall lets it in. Ingress reaches backends by
LAN address, so any app it routes to on the mini would hit the firewall.

The ways round it:

- **Turn the application firewall off on the mini only,** and use pf to let
  only ingress reach app ports. This matches how ingress is the front door
  for everything else. pf rules are plain config, so Nix can own them.
- **Allow-list each binary** with `socketfilterfw`. Nix store paths change
  on every rebuild, so the list would go stale on every switch.
- **Keep Tailscale Serve** for mini apps and give up on
  `*.shaneplunkett.com` names for them.

## What nix-darwin can do

Checked against the nix-config flake in October 2026.

- `services.tailscale` exists, so the Homebrew app could become a declared
  daemon. Serve config and tags would still need a step of their own.
- `services.prometheus.exporters.node` exists, so a scrape and a HostDown
  alert are straightforward.
- There's no `services.alloy` and no `services.restic`. Both would be
  hand-written launchd daemons. macOS has no journal, so Alloy would tail
  log files such as `~/Library/Logs`.
- `networking.applicationFirewall` exists, so turning it off for the mini is
  a one-host override.

## Questions to answer

- **Which repo owns the mini?** Colmena only deploys NixOS, so the mini
  can't just join the hive. It could stay in nix-config and import shared
  conventions, or this repo could grow a `darwinConfigurations` output.
- **How does it deploy?** A merge here could switch it from the builder, or
  it could keep switching from nix-config by hand.
- **Is it a server or a desktop?** It auto-logs in so launchd agents get the
  keychain. That's a desktop habit, and it's why vex-code is an agent rather
  than a daemon. Hive hosts run everything as system services.
- **What needs backing up?** vex-code's state under `~/.t3` is the obvious
  one. Models and the Nix store can be downloaded again.
- **Does it move off Tailscale Serve entirely,** or keep it for things like
  vex-code that already work?

## Stale bits in nix-config

These turned up while looking at the mini and are worth fixing whatever
happens.

- `home/shane/modules/common/ssh.nix` still has `proxy`, `technitium`,
  `technitium2` and `mcphub` host aliases.
- `hosts/desktop/modules/networking.nix` describes Technitium as the
  tailnet's resolver. Blocky replaced it.
