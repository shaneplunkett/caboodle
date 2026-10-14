# unifi-cli

Read-only Go CLI for Shane's UniFi Cloud Gateway Max.

Auth via official `X-API-KEY` header. Controller URL, key, and site are
loaded from env vars by the nix home-manager wrapper at
`~/nix-config/home/shane/modules/common/unifi.nix`. The wrapper pulls
the API key from Bitwarden (rbw entry: **Unifi API Key**) at every
invocation so rotation is `edit-in-web-UI → rbw sync` — no rebuild.

JSON to stdout (jq-friendly) by default; `--pretty` for human-readable
indentation. Errors to stderr.

## Surface

| Command | Description |
|---|---|
| `unifi status` | Synthesised health: WAN, LAN, WLAN, gateway, alarms |
| `unifi sites` | List sites |
| `unifi devices` | List UniFi devices (`--mac`, `--name`, `--full`) |
| `unifi clients` | List network clients (`--all`, `--wired`, `--wireless`, `--mac`, `--full`) |
| `unifi events` | Recent events (`--minutes`, `--limit`, `--key`) |
| `unifi alarms` | Active alarms (`--include-archived`) |
| `unifi networks` | Configured LAN/VLAN networks |
| `unifi wifi` | Configured WLANs |
| `unifi wan` | WAN-side detail with uplink port stats |
| `unifi speedtest` | Trigger gateway speedtest, wait for result |

## Build

Iteration is just `go build` — the nix wrapper points at the binary in
this directory, so rebuilding doesn't require `nixos-rebuild`.

```bash
cd ~/Projects/personal/unifi-cli
go build -o unifi .
```

## Env vars

| Var | Default | Purpose |
|---|---|---|
| `UNIFI_API_KEY` | (required) | X-API-KEY header value |
| `UNIFI_CONTROLLER_URL` | `https://192.168.1.1` | Controller base URL (no trailing slash) |
| `UNIFI_SITE` | `default` | Site name (most home users have one) |
| `UNIFI_TIMEOUT` | `10s` | Per-request timeout |

Set by the nix wrapper. Override at the shell only if you're debugging.
