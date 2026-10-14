# Glance

How the [Glance](https://github.com/glanceapp/glance) dashboard is put
together and extended. For what's actually configured, read the Nix.

## Layout

```
glance/
  default.nix            # NixOS module: services.glance, its secrets, the page list
  theme.nix              # colours and theme presets
  pages/
    <page>.nix           # one page: its columns and which widgets go where
  widgets/
    <name>/
      default.nix        # the widget's settings
      template.html      # the widget's Go template (custom-api widgets)
```

`default.nix` is a NixOS module, and a host opts in by importing the folder.
Pages and widgets are **not** modules. They're plain attrsets pulled in with
`import`. When one needs something from the module (`nodes`, `secrets`,
`lib`), it becomes a function taking just those, and the caller passes them:
`(import ../widgets/alerts { inherit nodes; })`.

Widgets built from the hive (like the service tiles, generated from the
ingress host's `virtualHosts`) update themselves when the hive changes, so
there's nothing to keep in sync by hand.

## Gotchas

- `settings.server.host` defaults to `127.0.0.1`, so nothing off the box
  (like a reverse proxy) can reach Glance until it's `0.0.0.0`.
- `environmentFile` takes **one** path, not a list.
- The config the module writes to `/run/glance/glance.yaml` is JSON. That's
  valid YAML, so Glance reads it fine, but it matters for `$include` (below).

## Secrets

The module asks for its secrets by name with `homelab.secrets` (see
`modules/agenix`), and `environmentFile` points at the decrypted file. Glance
substitutes `${VAR}` placeholders from it when it starts, and doesn't care
what the variables are called.

The module also accepts `{ _secret = "/path"; }` in place of any single
setting, which reads a raw value from a file with no `KEY=` line. It's
substituted as root before Glance starts, so it works with root-owned agenix
files and avoids juggling more than one `environmentFile`.

## Escaping `${...}`

Glance and Nix both use `${...}`. In a Nix string, write `\${VAR}` so Nix
leaves it alone and Glance receives `${VAR}`. In `''` strings it's
`''${VAR}`. Templates in `.html` files don't need escaping, because
`builtins.readFile` never interpolates.

## Adding a community widget

Widgets come from
[glanceapp/community-widgets](https://github.com/glanceapp/community-widgets).
Each one lives in `widgets/<name>/README.md` as a YAML code block. There are
no standalone `.yml` files to fetch.

1. **Copy the YAML block** from the widget's README.
2. **Template:** everything under `template: |` goes into
   `widgets/<name>/template.html`, minus the block's indentation (usually 4
   spaces). Don't change anything else; the `\"` escapes inside `{{ }}`
   belong to the Go template.
3. **Settings:** everything above `template:` becomes
   `widgets/<name>/default.nix`. `key: value` turns into `key = "value";`,
   nested keys become nested attrsets, and
   `template = builtins.readFile ./template.html;` goes at the end. Replace the
   widget's placeholder env vars with real values or our own secrets, escaped
   as `\${...}`. Drop `allow-insecure: true` for anything with a real
   certificate.
4. **Add it to a page:** `(import ./widgets/<name>)` in a `widgets` list.
5. **Check and ship:** `git add` the new folder (flakes can't see untracked
   files), then `colmena build --on <host>`, then apply.

Add it to this list of widgets adapted from community-widgets, so updates
know where to look: `proxmox-ve-stats` (from `proxmox-ve-stats`), `unraid`
(from `unraid-widget`).

### Why not `$include`?

Glance's `$include` directive looks like the obvious way to pull in widget
YAML, but it doesn't work from Nix. Glance finds includes with a regex that
expects an unquoted YAML line like `- $include: path`. The NixOS module writes
JSON, where it comes out as `"$include": "..."`, so the regex never matches.

## Writing a widget

Most widgets are `custom-api`: Glance calls `url` with `headers`, puts the
response in `.JSON`, and renders `template` into HTML on the server. The
browser never sees the API or its token.

Inside the template:

- `.JSON.String "path"`, `.JSON.Int`, `.JSON.Float`, `.JSON.Bool` read single
  values; `.JSON.Array "path"` returns a list.
- Paths use [GJSON syntax](https://github.com/tidwall/gjson/blob/master/SYNTAX.md).
  `data.#(type=="lxc")#` keeps every item in `data` whose `type` is `lxc`, and
  `|` chains another filter onto the result.
- `len (...)` counts a list.
- Glance's own CSS classes (`flex`, `color-highlight`, `size-h3`,
  `uppercase`) make the output match the theme.

The full reference is the `custom-api` section of Glance's
[configuration docs](https://github.com/glanceapp/glance/blob/main/docs/configuration.md#custom-api).
