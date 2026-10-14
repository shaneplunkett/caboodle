# Shared MCP servers

The one MCP server registry for every Home Manager profile that imports
`home/shane/modules/common/ai`. Claude Code and Codex both read it, so keep
servers here unless one is genuinely harness-specific.

The Codex module drops two things when it converts a server. A literal
`bearer_token`, which Codex rejects even over HTTP (`bearer_token_env_var`
and headers work). And any `oauth` metadata, which Codex takes as an order to
start an OAuth flow while it initialises.

## Adding a server

Prefer a pinned Nix package for the server binary over `npx -y ...@latest`.
That depends on mutable network state, and breaks when harnesses launch MCPs
with different `PATH`s.

A server that needs a secret gets a wrapper that reads it from rbw when it
starts, as `context7` does in `default.nix`, so the secret stays out of the
Nix store. Header values pass through to each harness literally, so an
`{env:...}` placeholder isn't expanded.
