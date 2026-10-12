# DMZ playground

A public way in to things running on homelab hardware, without opening the
LAN to the internet. Three things want it so far:

- Shane's mum wants to request things in Seerr again, which she could do
  back when it was public.
- `shaneplunkett.com` could be a real site.
- Toy projects need somewhere public to live, on hardware that can't run up
  a cloud bill.

Shane and Vex worked this out in conversation in October 2026. Nothing here
is built yet. Prices and limits were checked at the time, and the sources are
at the bottom.

## Decisions

- **A Cloudflare Tunnel is the way in.** No port forwards and no VPS. The
  static IP makes a VPS unnecessary for addressing, and a tunnel leaves no
  inbound port to find.
- **A new DMZ VLAN,** with UniFi zone policies in Terraform next to the IoT
  ones. The DMZ can reach the internet and a named list of app ports, and
  nothing else on the LAN.
- **`cloudflared` runs in its own LXC in the DMZ,** with its own tunnel and
  token, separate from the brain's. Tunnel routes do the per-hostname
  routing, so the DMZ host doesn't need nginx.
- **Toys run inside the DMZ.** Internal apps like Seerr stay where they are
  and get a firewall pinhole from the `cloudflared` host to their one port.
- **Cloudflare Access sits in front of everything people use.** Apps keep
  their own logins behind it, so getting in takes two separate sign-ins.
- **Git from inside the tailnet stays on SSH, unchanged.** Clients outside it
  use HTTPS with an Access service token and a Forgejo token.
- **Seerr is the first slice.** It proves the whole path end to end.

## 1. Ways in

### Port forward to a locked-down reverse proxy

The classic setup works, and the ingress host already has most of it: DNS-01
wildcard certs, so port 80 never needs to be open, and oauth2-proxy with
Pocket ID. It was ruled out because a tunnel needs no open port at all, and
because of the problems with pointing the existing ingress outward, covered
in [section 2](#2-network-shape).

### Proxied DNS with a port forward

Cloudflare's proxied DNS hides the origin IP in DNS answers only. Port 443
is still open on the router, and internet-wide scanners such as Censys and
Shodan connect to every address, read the certificate, and link the IP to
the domain. With a static IP, a leaked address stays leaked.

Doing it properly takes two more locks:

- Restrict the port forward to [Cloudflare's IP ranges](https://www.cloudflare.com/ips/).
  Terraform's `cloudflare_ip_ranges` data source can feed a UniFi IP group,
  so the list keeps itself current.
- Turn on [Authenticated Origin Pulls](https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/),
  so the origin only answers connections that present Cloudflare's client
  certificate.

That's two things to get right, and a mistake in either one exposes the
origin again. A tunnel avoids both.

### Cloudflare Tunnel (chosen)

`cloudflared` connects outbound to Cloudflare, so nothing inbound is open
and the home IP appears nowhere. The brain already runs this pattern
(`modules/services/vex-brain/tunnel.nix`).

Limits, which also apply to proxied DNS:

- **HTTP(S) only.** Plain SSH doesn't go through. A client can tunnel SSH
  only by running [`cloudflared access ssh` as a ProxyCommand](https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/).
- **Cloudflare decrypts traffic at its edge.**
- **Request bodies are capped at 100 MB** on the Free plan
  ([limits](https://developers.cloudflare.com/workers/platform/limits/)).
  Large HTTPS git pushes can hit this.

In return the free plan includes DDoS protection, the WAF, and Access.

### Tailscale Funnel

Funnel is a good fit for webhook receivers, and a poor fit for a front door
([docs](https://tailscale.com/kb/1223/funnel)).

Better than a tunnel:

- The relay never decrypts. TLS ends on the node.
- There's no 100 MB body cap, and Funnel carries any TLS-wrapped TCP, not
  only HTTPS.

Worse or the same:

- Names are always `node.tailnet.ts.net`. Custom domains aren't supported.
- It only listens on 443, 8443 and 10000, and it only carries TLS, so plain
  SSH doesn't work.
- Tailscale applies bandwidth limits that it doesn't publish and that can't
  be configured.
- No WAF, DDoS layer or Access-style login. Anything funnelled is fully
  public, and the app's own sign-in is the only lock.
- The `.ts.net` certificate lands in public certificate transparency logs,
  which publishes the hostname.

Use it for one-off webhooks from senders that sign their requests, such as
GitHub or Square, where the URL doesn't matter.

### VPS with WireGuard home

A VPS front door can carry any protocol, keeps TLS in Shane's hands, and has
no body cap. It isn't needed for now, because the static IP already gives a
fixed address and the tunnel covers HTTP. Keep it as the fallback if
something needs non-HTTP access from outside the tailnet.

Cloudflare doesn't sell a VPS.
[Containers](https://developers.cloudflare.com/containers/) need Workers
Paid (US$5 a month), take requests only through a Worker, have no public IP
or inbound SSH, and sleep when idle. They can't act as a front door.

Australian options, checked October 2026:

| Provider | Region | Entry price |
|---|---|---|
| BinaryLane | Melbourne, Sydney, Brisbane, Perth | A$4.90 a month ex GST (1 vCPU, 1 GB) |
| Vultr | Melbourne, Sydney | about US$5 a month |
| Oracle Cloud Always Free | Melbourne, Sydney | free, Arm capped at 2 OCPU and 12 GB |
| Hetzner Cloud | Singapore, the nearest | more than BinaryLane after its price rises |

BinaryLane is the pick if one's ever needed. Oracle halved its free Arm
allowance on 15 June 2026 without announcing it
([InfoQ](https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/)),
so nothing that matters should depend on it.

## 2. Network shape

```text
internet -> Cloudflare edge -> tunnel (outbound from the DMZ)
                                 |
                       DMZ VLAN: cloudflared LXC, toy hosts
                                 |  pinholes to named host:port pairs only
                       LAN: arr (Seerr), forge, ...
```

Zone policies:

| From | To | Rule |
|---|---|---|
| DMZ | internet | allow (tunnel, package installs) |
| DMZ | named app ports on the LAN | allow, one rule per pinhole |
| DMZ | rest of the LAN, IoT | deny |
| LAN | DMZ | allow, for management |

### Why not point the existing ingress outward

- `docs/pve/auth.md` says apps behind the oauth2-proxy gate skip their own
  logins because they trust the ingress. Some paths are deliberately left
  open so the apps can call each other. That's fine on the LAN, and it
  becomes a set of public holes on the internet.
- The ingress host holds the wildcard certificate and the `cloudflare-dns`
  token, which can edit DNS on every personal zone. A public-facing box
  shouldn't hold either. The `cloudflared` LXC gets nothing except its own
  tunnel token.

### Toys inside, apps behind pinholes

Toy projects are the least trusted code in the homelab, so they run on the
DMZ VLAN itself. If one is compromised, it sits somewhere that can't reach
the LAN. Internal apps stay where they are, and each one exposed gets a
single policy from the `cloudflared` host to its port.

### Split horizon

Blocky answers for all of `shaneplunkett.com` on the LAN, so a hostname with
a public tunnel route still resolves to the internal ingress at home. Home
traffic skips Cloudflare, and no changes are needed for it.

## 3. Sign-in

Access is free for up to 50 users. Each public hostname gets an Access app
in Terraform (`terraform/cloudflare*.tf` already owns the Access apps).

For people outside the homelab, use Google login or Access's
[one-time PIN](https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/one-time-pin/).
One-time PIN emails a code to any address the policy allows, with nothing
to set up. Set a long session, about a month, so occasional users aren't
signing in on every visit.

Access could use Pocket ID as a generic OIDC login method, which would fit
the repo's rule that every web app signs in through Pocket ID. The catch is
that the browser goes to Pocket ID to sign in, so Pocket ID itself would
have to become public. Guests using Google or one-time PIN avoids that. See
the open questions.

## 4. Git from outside the tailnet

Forgejo's push and pull mirrors only connect outbound, so mirroring to and
from GitHub needs no way in at all. Only people pushing from outside the
tailnet need one.

- **Inside the tailnet:** `forgejo@forge:<owner>/<repo>.git` over SSH, as
  now, with no size limit.
- **Outside:** HTTPS to `git.shaneplunkett.com` through the tunnel. Git
  can't follow a browser login, so each client gets an Access
  [service token](https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/)
  sent as headers, plus its own Forgejo token. Either one can be revoked
  per client.

```sh
git config --global http.https://git.shaneplunkett.com/.extraHeader "CF-Access-Client-Id: <id>"
git config --global --add http.https://git.shaneplunkett.com/.extraHeader "CF-Access-Client-Secret: <secret>"
```

- Do a large first push over the tailnet, because of the 100 MB cap.
- A client that needs SSH either runs `cloudflared access ssh` or joins the
  tailnet.

Repos that someone outside the homelab edits for their own business stay
GitHub-first, and the forge pull-mirrors them. Otherwise a homelab outage
stops them working and lands on Shane to fix.

## 5. First slice: Seerr

Seerr is `routes.overseer` in `modules/arr/seerr.nix`. It isn't behind the
oauth2-proxy gate, and its own Plex sign-in is the only login.

1. Create the DMZ VLAN and its zone policies in Terraform.
2. Create the `cloudflared` LXC in the DMZ, with its tunnel token in agenix
   and routes in Terraform like the brain's.
3. Add a pinhole from the `cloudflared` LXC to Seerr's port on `arr`.
4. Route `overseer.shaneplunkett.com` through the tunnel to it.
5. Put an Access app in front that allows Shane's mum by email, with Google
   login or one-time PIN.

Done is Shane's mum requesting something from outside the house.

## 6. Later

- **A toy runner.** A DMZ LXC that runs containers, so a new toy is a deploy
  and a tunnel route. Wait until there's an actual toy for it.
- **`shaneplunkett.com`.** If it's static, Workers on the Free plan is an
  option too. The Free plan has no paid overage and stops serving past
  100,000 requests a day
  ([pricing](https://developers.cloudflare.com/workers/platform/pricing/)),
  so it can't bill. On homelab hardware, it's another DMZ toy.
- **Moving the homelab onto a servers VLAN.** This is good hygiene and a
  separate project, with known snags:
  - Home Assistant needs to stay on the main LAN, or keep an interface
    there, because the Apple border routers must be on the main LAN for
    Thread (`docs/pve/home.md`).
  - Some things use main-LAN addresses, such as the Cube NFS mounts, and
    Terraform pins MAC addresses for UniFi DHCP reservations.
  - Every VLAN needs allow rules to reach Blocky.
  - Tailscale subnet routes and mDNS discovery have to cross the new VLAN.

## Side findings

- **The home IP doesn't look tied to the domains.** In October 2026, no
  record in any Cloudflare zone pointed at it, HackerTarget's passive DNS
  linked no names to it, and Shodan knew it only by the ISP's generic
  reverse name. Paid history databases such as SecurityTrails weren't
  checked. With a tunnel, the question stops mattering, because there's no
  open port to reach behind Cloudflare.
- **Plex is the only open port Shodan sees.** Keep it updating. The 2022
  LastPass breach started with an unpatched Plex server on an engineer's
  home computer
  ([Wikipedia](https://en.wikipedia.org/wiki/2022_LastPass_data_breach)).

## Open questions

- **DNS for the DMZ.** Public resolvers keep the DMZ off Blocky, but then
  tunnel routes have to name origins by address. The alternative is a
  pinhole to Blocky on port 53.
- **Guests on Pocket ID or not.** Google login and one-time PIN keep Pocket
  ID private. Using Pocket ID for everyone means making it public.
- **What runs the toys:** one Podman LXC for all of them, or one LXC per
  toy.

## Sources

- Cloudflare IP ranges: https://www.cloudflare.com/ips/
- Authenticated Origin Pulls: https://developers.cloudflare.com/ssl/origin-configuration/authenticated-origin-pull/
- Request body limits by plan: https://developers.cloudflare.com/workers/platform/limits/
- Workers pricing and Free plan limits: https://developers.cloudflare.com/workers/platform/pricing/
- Cloudflare Containers: https://developers.cloudflare.com/containers/
- Access service tokens: https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/
- Access one-time PIN: https://developers.cloudflare.com/cloudflare-one/integrations/identity-providers/one-time-pin/
- SSH through Access with `cloudflared`: https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/use-cases/ssh/ssh-cloudflared-authentication/
- Zero Trust free plan, 50 users: https://zerometric.net/research/cloudflare-zero-trust-free-plan-limits-2026
- Tailscale Funnel: https://tailscale.com/kb/1223/funnel
- BinaryLane pricing: https://www.whtop.com/review/binarylane.com.au
- Oracle free tier cut: https://www.infoq.com/news/2026/07/oracle-cloud-free-tier-limits/
- Hetzner Singapore: https://www.hetzner.com/cloud-singapore
- 2022 LastPass breach: https://en.wikipedia.org/wiki/2022_LastPass_data_breach
