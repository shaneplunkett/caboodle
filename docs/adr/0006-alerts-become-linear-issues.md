# Alerts become Linear issues through a bridge beside Alertmanager

Alertmanager's one receiver was a Discord webhook, and Discord is leaving
with the forge. Everything else Shane reads is in Linear, so alerts go there
too. Linear's inbox only shows changes to things Linear already knows about,
an issue assigned, a comment on something followed, a reminder; nothing can
write a message into it. So an alert has to become an issue. Alertmanager
has no Linear receiver and Linear has no Alertmanager intake, so a bridge
sits between them: a small Go program in `pkgs/`, standard library only,
with a module beside Alertmanager's, listening on loopback on the monitoring
host. Alertmanager posts each alert to it and it posts to `api.linear.app`
as a Linear OAuth app with client credentials, so the issues come from the
app and Shane's inbox fires. Linear never notifies you about your own
actions, so a personal API key would file issues nobody hears about. The
client id and secret are agenix secrets, and the bridge fetches a new token
when the old one expires.

What the bridge does, and does not do:

- **One issue per alert, not per group.** Two disks filling on two hosts are
  two jobs. A firing alert becomes an issue in Engineering's Triage,
  assigned to Shane, labelled `bug`, `needs-triage` and `repo:caboodle`,
  critical as Urgent and warning as Medium. The summary is the title; the
  body carries the condition, the `check` command as a code block, where it
  is, and the same view link Discord got.
- **Still firing changes nothing.** The bridge finds the alert's open issue
  in Linear and leaves it alone, so Alertmanager's 24h repeat files no
  twins. It keeps no state of its own.
- **Resolved is a comment, never a close.** `SmartctlSectorsGrowing`
  resolves itself when its one-day window rolls past, with the drive no
  better, and `BackupStale` resolves when one backup squeaks through. A
  close by the bridge would hide the thing worth looking at. The bridge
  comments how long the alert lasted; Shane closes the issue when the job
  is done.
- **A re-fire after a close is a fresh issue**, linking the last one. A
  closed issue coming back to life on its own is auto-close in reverse.
- **The Watchdog goes through the bridge** on its way to healthchecks.io,
  so the dead man's switch covers the bridge as well as Alertmanager.
- **Traffic goes one way.** Linear never calls in, so the bridge has no
  public name, no ingress route and no gate.
- **Standard library only.** Alertmanager's payload is JSON and Linear's API
  is an HTTP POST carrying a GraphQL string; Go's standard library does
  both. Renovate has nothing to bump, and nixpkgs' Go is the only thing
  that ever rebuilds it.

## Considered options

- **Email.** Linear's "create issues by email" toggle gives a team an
  intake address, and Alertmanager has an email receiver, so Gmail's SMTP
  and an app password would do it with no code at all. But the basic
  intake ignores replies, so a resolved alert can never reach its issue,
  and nothing but a long `repeat_interval` stops a flapping alert filing
  twins. Config-only was tempting and the trade wasn't worth it.
- **n8n.** A webhook node in and the Linear node out, no code of ours. It
  is also a Node app with a database, a web UI that needs the oauth2-proxy
  gate, workflows that live in that database rather than git, and
  credentials outside agenix, all for one job. "It can do anything" is the
  trap. SHA-176 closed with this; it reopens the day a second glue job
  shows up.
- **Waggle**, the Discord bot planned on 8 Oct in Go with `disgo`, in its
  own repo as a flake input. Both its reasons went: GitHub's Linear
  integration covers the PR cards, and Discord is the thing leaving. What
  was left of it is this bridge, so it keeps the spot in the rack and loses
  the name, the repo and the gateway connection.
- **Auto-close on resolve.** Cleaner for `HostDiskFilling`, wrong for every
  alert that resolves by its window moving rather than by the problem
  going away.
- **Reopen on re-fire.** One issue per problem over its whole life, but it
  revives something Shane deliberately closed.
- **Linear calling back**, so closing an issue silences the alert. That
  needs a webhook and a public URL through the ingress. An add-on later if
  it's ever wanted, not part of this.

## Consequences

- 0005 left "moving Alertmanager off Discord" open; this closes it. The
  other item it left open, a failed deploy reaching Linear's inbox
  (SHA-291), joins this work: the runner posts to the same bridge over the
  LAN, and when it does the bridge listens on the LAN instead of loopback.
- The Discord webhook secret goes. `README.md`'s monitoring section and the
  Alertmanager notes in `modules/services/README.md` and
  `docs/internet-down.md` change with the build. With DNS down the alert
  still can't reach Linear, and Grafana stays the fallback.
- Registering the OAuth app in Linear's settings is the one step done by
  hand.
- Alert issues wait in Triage beside the agents' tickets, and the inbox
  shows them because they are assigned, not because anyone holds triage
  responsibility.
