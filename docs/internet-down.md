# When the internet's broken

The forge, the DNS hosts and the monitoring stack are all on the LAN, so a
bad ISP day can lock you out of the things you'd fix it with. This is the
order to work through, from a laptop on 4G.

## How DNS is meant to fail

Unbound forwards everything to Quad9 and Cloudflare over DoT. Blocky asks
Unbound first, and if Unbound times out or returns SERVFAIL it asks Quad9
and Cloudflare itself, also over DoT. So LAN DNS should only break when the
internet can't reach either of them.

Latency matters more than you'd think. A new DoT connection takes three
round trips before the first answer, and Blocky's upstream timeout is 3s, so
round trips over about 1s start failing lookups. Unbound keeps its
connections open once they're up, so failures cluster after a restart or a
quiet spell.

## Find which layer is broken

On dns1 or dns2:

```sh
ping -c 20 "$(ip route | awk '/default/ {print $3}')"   # LAN
ping -c 20 1.1.1.1                                      # ISP
dig @127.0.0.1 example.com                              # Blocky
dig @127.0.0.1 -p 5335 example.com                      # Unbound
```

Then see who's answering:

```sh
journalctl -u blocky --since -10m | grep -o 'response_reason=RESOLVED ([^)]*)' | sort | uniq -c
journalctl -u blocky --since -10m | grep -c 'no resolver returned an answer'
```

Answers from `tcp-tls:` mean Unbound is failing and Blocky is covering for
it. `no resolver returned an answer` means all three failed, which is the
internet, not the config.

## Get onto the hosts

Tailscale's DNS forwards to dns1 and dns2, so when they're broken the laptop
can stop resolving names, tailnet ones included. Turn it off and use tailnet
addresses, which `tailscale ip` reads from Tailscale itself without DNS:

```sh
sudo tailscale set --accept-dns=false
ssh -o HostKeyAlias=dns1 -o StrictHostKeyChecking=accept-new root@"$(tailscale ip -4 dns1)"
```

The builder does the deploys, so the laptop may never have seen the DNS
hosts' keys. `HostKeyAlias` files the key under the name rather than the
address, and `accept-new` takes it on first contact.

Turn it back on afterwards with `sudo tailscale set --accept-dns=true`.

## Get the repo

The forge remote uses the tailnet name `forge`. If it won't resolve, either
fetch from the GitHub mirror:

```sh
git fetch github
```

or reach the forge by address:

```sh
GIT_SSH_COMMAND='ssh -o HostKeyAlias=forge' \
  git fetch "forgejo@$(tailscale ip -4 forge):shane/caboodle.git" main
```

Check how old the checkout is before trusting what it says:
`git log -1 --format=%cr FETCH_HEAD`.

## Gotchas

- Alerts go to Discord, and Alertmanager needs DNS to find it. With DNS
  down it can't resolve `discord.com`, so the alert fires and never
  arrives. Look in Grafana instead.
- Deploying from the laptop mid-incident leaves the host on something
  `main` doesn't have. The next merge deploy quietly puts `main` back and
  restarts whatever differs, so land the fix as a PR before anything else
  merges.
- `unbound-control forward_add` and other runtime changes vanish on the
  next restart, and every deploy that touches Unbound restarts it.
