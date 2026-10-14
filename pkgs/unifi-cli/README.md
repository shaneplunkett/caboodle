# unifi-cli

Read-only Go CLI for Shane's UniFi gateway. `unifi --help` lists what it
can do.

The home-manager wrapper in `home/shane/modules/agent-clis/default.nix` reads
the API key from rbw (`Unifi API Key`) on every call, so rotating it is an
edit in Bitwarden and `rbw sync`, with no rebuild.

## Build

`default.nix` packages it, and the workstations get it through the overlay in
`pkgs/overlays.nix`, so a change reaches the wrapper on the next switch. For
a quicker loop, build it here and run it with the env vars `main.go` reads:

```bash
go build -o unifi .
```

A change to `go.mod` or `go.sum` needs a new `vendorHash` in `default.nix`.
