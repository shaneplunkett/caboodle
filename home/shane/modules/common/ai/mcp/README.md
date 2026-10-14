# Shared MCP servers

This module is the canonical MCP server registry for Home Manager profiles that
import `home/shane/modules/common/ai`.

## Why this shape

- `programs.mcp.servers` is the shared Home Manager schema.
- `programs.claude-code.enableMcpIntegration = true` converts it to Claude
  Code's generated MCP plugin.
- The Codex module converts it to Codex's `mcp_servers` shape with
  transport-aware filtering. `command` servers stay stdio-only, `url` servers
  stay streamable-HTTP-only, `headers` maps to `http_headers` only for HTTP,
  and `disabled` maps to `enabled`. It drops a literal `bearer_token`, which
  Codex rejects even over HTTP (`bearer_token_env_var` and headers work), and
  any `oauth` metadata, which Codex takes as an order to start an OAuth flow
  while it initialises.
- Keep server definitions here unless a server is genuinely harness-specific.

## Adding a server

Add a new entry under `programs.mcp.servers` in `default.nix`:

```nix
programs.mcp.servers = {
  my-server = {
    command = "${pkgs.some-mcp-package}/bin/some-mcp-server";
    args = [ "--flag" "value" ];
    env = {
      SOME_ENV = "value";
    };
  };
};
```

A server that needs a secret gets a wrapper that reads it from rbw when it
starts, as `context7` does in `default.nix`. Header values pass through to
each harness literally, so an `{env:...}` placeholder isn't expanded.

Prefer pinned Nix packages or derivations for server binaries. Avoid runtime
`npx -y ...@latest` for durable servers; it depends on mutable network state and
can break when different harnesses launch MCPs with different `PATH` values.

Runtime credential lookup wrappers are acceptable when credentials must stay out
of the Nix store. Keep the server binary pinned; keep secrets runtime-only.
