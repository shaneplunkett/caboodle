# Glance

How the [Glance](https://github.com/glanceapp/glance) dashboard is put
together and extended. For what's actually configured, read the Nix.

`default.nix` is a NixOS module, and a host opts in by importing the folder.
Pages and widgets are **not** modules. They're plain attrsets pulled in with
`import`. When one needs something from the module (`nodes`, `secrets`,
`lib`), it becomes a function taking just those, and the caller passes them:
`(import ../widgets/alerts { inherit nodes; })`.

## Gotchas

- `settings.server.host` defaults to `127.0.0.1`, so nothing off the box
  (like a reverse proxy) can reach Glance until it's `0.0.0.0`.
- `environmentFile` takes **one** path, not a list.
- The config the module writes to `/run/glance/glance.yaml` is JSON. That's
  valid YAML, so Glance reads it fine, but it matters for `$include` (below).

## Secrets

The module accepts `{ _secret = "/path"; }` in place of any single setting,
which reads a raw value from a file with no `KEY=` line. It's substituted as
root before Glance starts, so it works with root-owned agenix files and
avoids juggling more than one `environmentFile`.

## Escaping `${...}`

Glance and Nix both use `${...}`. In a Nix string, write `\${VAR}` so Nix
leaves it alone and Glance receives `${VAR}`. In `''` strings it's
`''${VAR}`. Templates in `.html` files don't need escaping, because
`builtins.readFile` never interpolates.

## Adding a community widget

Widgets come from
[glanceapp/community-widgets](https://github.com/glanceapp/community-widgets),
each as a YAML block in its `widgets/<name>/README.md`.

1. Everything under `template: |` goes into `widgets/<name>/template.html`,
   minus the block's indentation. Leave the `\"` escapes inside `{{ }}`
   alone, they belong to the Go template.
2. Everything above `template:` becomes `widgets/<name>/default.nix`, with
   `template = builtins.readFile ./template.html;` at the end. Swap the
   widget's placeholder env vars for real values or our own secrets, escaped
   as `\${...}`. Drop `allow-insecure: true` for anything with a real
   certificate.
3. Add `(import ../widgets/<name>)` to a page's `widgets` list.
4. `git add` the new folder, since flakes can't see untracked files.

### Why not `$include`?

Glance's `$include` directive looks like the obvious way to pull in widget
YAML, but it doesn't work from Nix. Glance finds includes with a regex that
expects an unquoted YAML line like `- $include: path`. The NixOS module writes
JSON, where it comes out as `"$include": "..."`, so the regex never matches.

## Writing a widget

Most widgets are `custom-api`, which renders its template on the server, so
the browser never sees the API or its token. The reference is the
`custom-api` section of Glance's
[configuration docs](https://github.com/glanceapp/glance/blob/main/docs/configuration.md#custom-api).
