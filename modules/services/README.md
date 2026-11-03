# Services

One folder per service. `default.nix` is the NixOS module a host imports, and
anything bigger (alert rules, templates, dashboards) sits in its own file next to
it. Alert rules for a service live with that service, even when they're loaded
by Prometheus on another host.

## Alertmanager

- The config goes through envsubst so the healthchecks.io ping URL can come
  from an env file. That means the config can't contain a stray `$`, and
  `checkConfig` is off because the placeholder URL isn't valid at build time.
- Alerts go to the Linear bridge's webhook on loopback, and `docs/adr/0006`
  says why the bridge files and comments but never closes. Alertmanager only
  retries a 5xx and retries the whole post, so the bridge answers 5xx only for
  network failures and Linear's own 5xx. A retry storm against a refusing Linear
  burned 60+ issue numbers in the prototype.
- Everything else answers 200: Linear's refusals, such as its usage limit, and
  anything it answers that the bridge can't read. That alert is lost until
  Alertmanager next sends it, and the only sign is an error line in the bridge's
  journal. `journalctl -u linear-bridge` has one line per alert, with its verb,
  fingerprint and issue, so a missing issue can be traced from there.
- The Watchdog repeats every 2 minutes on its 0s/1m/1m route, not every minute,
  and SHA-304 sizes the healthchecks.io check from that. The prototype measured
  it on a desktop Alertmanager with the same timings, since Prometheus doesn't
  scrape the real one.
- The bridge listens on 9096 because Loki's gRPC server takes 9095 by default,
  and no module says so. A local build can't catch a port clash; the first sign
  was `bind: address already in use` in the bridge's journal after a deploy.

- The bridge has one other client. A failed deploy posts from the runner, through
  `scripts/report-deploy-failure.sh`, to the bridge's LAN address, in Alertmanager's
  shape. Alertmanager stays on loopback. The bridge has no login and anything that
  reaches it can file an urgent issue, so the firewall lets in only the addresses in
  `allowedSources`, the way paperless-gpt lets in only the ingress host. If the LAN
  address isn't up yet the bridge exits and `Restart` brings it back, so loopback
  waits on the LAN for those few seconds.
- A `DeployFailed` issue's card links to Prometheus's alerts page, like every card,
  because that URL is how the bridge finds the issue again. Prometheus has never
  heard of this alert, so the page is empty. The run's link is in the issue's body.
  Its annotations carry that link in the text, not as `generatorURL` or `dashboard`,
  since the bridge would label those a graph or a dashboard and add a time range.

## Prometheus

- Use `ruleFiles` with `pkgs.writeText`, one file per module. `rules` joins
  every module's strings into one file, so only the first group loads.
- Inside a container, node exporter's CPU numbers come from the host's
  counters and are wrong. Guests' CPU comes from Incus instead (see the
  [Incus README](incus/README.md#metrics)).
- Every alert rule but the Watchdog carries a `summary` (the title), a `condition` (the trigger
  in one sentence), a `description` (a paragraph to Shane: what it means, why
  it matters now, what to do first) and a `check` (one command that shows the
  thing).

## Alloy

- The nixpkgs package links `systemd-minimal-libs`, which can't read the
  journal, so it silently ships nothing. `LD_LIBRARY_PATH` points it at the
  full libsystemd.
- `config.alloy` has its own formatter: `alloy fmt` from the dev shell.
- `alloy validate` passing doesn't mean Alloy will load the config. The LogQL
  in a `stage.match` selector isn't parsed until Alloy starts, and one bad
  selector stops the whole pipeline, so every host quietly ships nothing.
  Before a pipeline change merges, actually run the changed `loki.process`
  block: feed it real lines with `loki.source.file`, send the output to
  `loki.echo`, and `alloy run` it locally.
- Selectors only take double-quoted LogQL strings, not backticks. Write the
  whole selector as an Alloy raw string so the quotes inside it don't need
  escaping.
- Debug lines are dropped before they reach Loki. Narrow that match if you
  ever need one service's debug output.
- Home Assistant writes every line to stderr, so journald marks them all
  `err`. Its block reads the real level from HA's own text and folds each
  traceback into the line that logged it.

## Unpoller

- The nixpkgs module has no `api_key` option, and its controller submodule
  isn't freeform, so the key goes in through unpoller's own environment
  config: `UP_UNIFI_DEFAULT_API_KEY=file://<path>` on the unit. The
  startup log says `=> API Key: true` when it took.
- On UniFi Network 11, unpoller before 5.5.1 drops
  `unpoller_device_uplink_latency_seconds` and the speedtest series, which
  the Internet dashboard reads. If those panels are empty, check the
  version first.

## nginx-ingress

- ACME uses `1.1.1.1` as its DNS resolver. The LAN's Blocky answers for the
  whole domain itself and would never see the challenge record.
- The `_` vhost is a catch-all that 404s unknown names, instead of nginx
  falling through to the first route.

## Blocky and Unbound

Blocky does ad blocking and local records, and asks Unbound on the same
host for everything else (`docs/internet-down.md` has the full chain). Both are fully
declared in Nix with no state, so redundancy is the same host module on two
hosts, dns1 on PVE and dns2 on Cube. Either machine can go down and DNS
stays up. There's nothing to cluster or back up.

- Unbound listens on `127.0.0.1:5335`. Blocky wants port 53 on every address,
  so the two can't share it, and systemd-resolved is off for the same reason.
- Blocky starts after Unbound. Otherwise it downloads its blocklists before
  Unbound is listening, every attempt fails, and the host answers without
  blocking anything until the next refresh.
- Blocky's default download timeout is 5 seconds, which cuts oisd off
  part-way and loads half the list without an error that stops anything.
  Check the per-source `import succeeded` counts in the journal.
- `customDNS.mapping` answers for a domain and every name under it, so
  `shaneplunkett.com` locally shadows anything that only exists in
  Cloudflare. Records like that (a CNAME to Pages, say) need their own entry,
  and CNAMEs have to go in `customDNS.zone` because `mapping` only takes IPs.
  TXT and mail records don't matter, since mail servers never ask this
  resolver.

## Tailscale

Every Nix host joins as `tag:homelab` with the OAuth client secret, so keys
don't expire. Incus guests get TUN from the `default` profile in
`modules/services/incus`.

- An OAuth secret used as an auth key makes ephemeral devices by default,
  which vanish when they go offline. `authKeyParameters` turns that off.
- `extraUpFlags` only apply on first join. Anything that has to stay true
  goes in `extraSetFlags`, which runs on every boot.
- Hosts never accept routes. They're on the LAN already, and a LAN machine
  that accepts the subnet route answers LAN clients through the tunnel and
  they never hear back. Macs and iPhones accept routes automatically, so if
  their LAN transfers are slow, check this first.
- Hosts don't accept tailnet DNS either. They keep the LAN resolvers from
  DHCP, so a Tailscale problem can't take DNS down with it, and the DNS hosts
  can't loop back to themselves.
- MagicDNS can't serve an owned domain, so the DNS hosts' tailnet IPs are the
  tailnet's global nameservers with Override on. A split-DNS entry for a
  domain beats the global nameservers, so delete stale ones rather than
  leaving them behind.
- Prometheus targets, the Loki URL and Blocky's records use
  `homelab.lanAddress`, never the tailnet name, so monitoring and DNS keep
  working when Tailscale doesn't.
