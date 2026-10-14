# Services

One folder per service. `default.nix` is the NixOS module a host imports, and
anything bigger (alert rules, templates, widgets) sits in its own file next to
it. Alert rules for a service live with that service, even when they're loaded
by Prometheus or Loki on another host.

Glance has its own [README](glance/README.md).

## Alertmanager

- The config goes through envsubst so the Discord webhook can come from an
  env file. That means templates can't contain a `$`, and `checkConfig` is
  off because the placeholder URL isn't valid at build time.
- Alerts go to Discord's Slack-compatible endpoint (`<webhook>/slack`), which
  allows colours, fields and links that the plain Discord format doesn't.

## Prometheus

- Use `ruleFiles` with `pkgs.writeText`, one file per module. `rules` joins
  every module's strings into one file, so only the first group loads.
- Inside an LXC, node exporter's CPU numbers come from the host's counters and
  are wrong. CPU per container comes from the PVE exporter instead.

## Loki

- With `auth_enabled = false` the tenant is called `fake`. The ruler's local
  storage expects rules under `<dir>/fake/`, hence the odd path.
- Kernel OOM messages aren't visible inside an LXC. The OOM alert matches
  systemd's "OOM killer" log line in `init.scope` instead.

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

## Gatus

- Conditions only compare integers, so fractional values (like CPU ratios)
  can't be checked there. Leave those to Prometheus.

## nginx-ingress

- ACME uses `1.1.1.1` as its DNS resolver. The LAN's Blocky answers for the
  whole domain itself and would never see the challenge record.
- The `_` vhost is a catch-all that 404s unknown names, instead of nginx
  falling through to the first route.

## Blocky and Unbound

Blocky does ad blocking and local records, and asks Unbound on the same
host for everything else (`docs/internet-down.md` has the full chain). Both are fully
declared in Nix with no state, so redundancy is the same host module on one
host per Proxmox node. There's nothing to cluster or back up.

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
don't expire. Containers get TUN from the drop-in in `proxmox/`.

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
