# Grafana dashboard skills for agents

- **Question:** Good skills people have made to help you be better at making Grafana dashboards? Or general guidance on using AI for making good, cute, consistent dashboards?
- **Researched:** 2026-10-17, deep

caboodle builds its dashboards in Nix: `modules/services/grafana/dashboards/`
has a shared helper file (`panels.nix`: datasources, `at` grid placement,
`query`, unit presets like `percent`) plus `dns.nix`, `hosts.nix` and
`logs.nix`. The agent reaches Grafana through the official mcp-grafana server.

## Sub-questions

1. Published agent skills, plugins and prompt packs for authoring Grafana dashboards: answered
2. Grafana Labs' own AI tooling for dashboards (Assistant, mcp-grafana, LLM plugin): answered
3. Dashboards-as-code tooling that keeps AI output consistent: answered
4. Established design guidance an agent can follow: answered (maturity model is a gap)
5. Practitioner write-ups on LLM-generated dashboards, failure modes, techniques: partly answered (no failure-mode write-ups exist)
6. Making dashboards cute and cohesive (themes, palettes, Catppuccin): answered

## Claims

Each claim, then its source, date and verdict.

- grafana/skills is an official Grafana repo (Apache-2.0) installable for Claude Code, Cursor and Codex, with a `dashboarding` skill in its `grafana-core` plugin.
  https://github.com/grafana/skills (2026-10-17): confirmed (star count ~285 vs 207 on a third-party listing, unverified).
- Install: `claude plugin marketplace add grafana/skills` then `claude plugin install grafana-core@grafana-skills` (pulls all 8 grafana-core skills); `npx skills add grafana/skills` also works.
  https://github.com/grafana/skills/blob/HEAD/README.md (undated): confirmed.
- `dashboarding` workflow: write payload JSON, `jq empty`, `POST /api/dashboards/db`, check returned version and GET by uid, open browser to confirm data. Raw JSON, no Foundation SDK, no metric discovery, no programmatic render.
  https://github.com/grafana/skills/blob/HEAD/skills/grafana-core/dashboarding/SKILL.md (2026-07-01): confirmed.
- `dashboarding` reference covers 24-column gridPos presets, units list, absolute thresholds with null base, legends, tooltips, transformations, links, annotations; no RED/USE, hierarchy or consistency guidance.
  https://github.com/grafana/skills/blob/HEAD/skills/grafana-core/dashboarding/references/json-schema.md (2026-07-01): confirmed.
- `dashboarding` targets OSS, Enterprise or Cloud via base URL + bearer token; never mentions mcp-grafana.
  grafana/skills dashboarding SKILL.md (2026-07-01): confirmed.
- `POST /api/dashboards/db` is deprecated in favour of `/apis/dashboard.grafana.app/v1/namespaces/{ns}/dashboards`; still works with a warning.
  https://github.com/grafana/grafana/blob/main/pkg/api/dashboard.go (2026-03-26): superseded: by the v1 dashboard API, https://grafana.com/docs/grafana/latest/developers/http_api/dashboard/.
- `dashboarding` pins `schemaVersion: 41`.
  grafana/skills dashboarding SKILL.md (2026-07-01): superseded: current migrator uses 42, the final v1 schema (DashboardMigrator.ts, 2025-09-05).
- wshobson/agents `grafana-dashboards` skill (MIT, ~41k-star repo) covers principles, RED/USE, a 10-item best-practices list, panels per dashboard type, and a file-provider `dashboards.yml` snippet; no workflow or verify step.
  https://github.com/wshobson/agents/blob/HEAD/plugins/observability-monitoring/skills/grafana-dashboards/SKILL.md (2026-09-29): confirmed (latest commit only removed dangling lines; content not refreshed).
- wshobson skill JSON is Angular-era (`graph` with `yaxes`, panel-level `alert` blocks); Grafana auto-migrates `graph` to `timeseries`.
  https://github.com/grafana/grafana/blob/main/public/app/features/dashboard/state/getPanelPluginToMigrateTo.ts (undated): superseded: by `timeseries` panels and unified alerting.
- wshobson Error Rate example multiplies by 100 with no unit set and no schemaVersion.
  wshobson grafana-dashboards SKILL.md (2026-09-29): confirmed.
- Install wshobson: `/plugin marketplace add wshobson/agents` then `/plugin install observability-monitoring@claude-code-workflows`, or `gh skill install wshobson/agents grafana-dashboards`.
  https://github.com/wshobson/agents (undated): confirmed.
- Neither skill gives explicit guidance on hallucinated metrics or wrong units.
  both SKILL.md files (2026-10-17): confirmed (absence).
- neelneelpurk Claude plugin: Foundation SDK in TS/Go/Python, Playwright preview, rubric critic; MIT, 0 stars, solo author.
  https://github.com/neelneelpurk/grafana-dashboard-developement-plugin (2026-07-06): confirmed.
- grafana/ai-marketplace `grafana-mcp` plugin stores service-account token in the system keychain; Viewer for reads, Editor for writes.
  https://github.com/grafana/ai-marketplace/blob/main/plugins/grafana-mcp/README.md (2026-10-15): confirmed ("~40 tools" and Docker requirement unconfirmed).
- Provisioning via a skill needs service-account permissions.
  https://mcp.directory/blog/claude-grafana-dashboards-skill-guide (2026-06-24): unconfirmed.
- mcp-grafana is official and active; latest release v2.0.2; needs Grafana 9.0+; documents `get_panel_image` rendering.
  https://github.com/grafana/mcp-grafana (2026-10-07 (release), pushed 2026-10-17): confirmed.
- On-prem Grafana Assistant (Grafana v13+) can create and update dashboards but needs a Grafana Cloud stack connection.
  https://grafana.com/docs/grafana/latest/administration/assistant (undated): confirmed.
- Advanced Assistant investigation features are Cloud-only.
  same (undated): unconfirmed.
- Grafana LLM plugin supports Anthropic and custom API providers.
  https://grafana.com/docs/grafana-cloud/ai-tools/llm-plugin/llm-setup (undated): confirmed.
- Grafana LLM plugin is public preview with Claude 3.5 models.
  https://grafana.com/grafana/plugins/grafana-llm-app (undated): unconfirmed.
- Foundation SDK exposes a `DashboardBuilder` API; Apache-2.0, active.
  https://github.com/grafana/grafana-foundation-sdk (2026-10-17): confirmed ("public preview" status unconfirmed).
- Grafonnet is a Jsonnet library generated from the same schemas as the Foundation SDK, installed via jb.
  https://github.com/grafana/grafonnet (2026-10-15): confirmed.
- grafanalib is in very early stages, under weaveworks, about ten months without a push.
  https://github.com/weaveworks/grafanalib (2025-12-08): confirmed.
- Grizzly is deprecated in favour of grafanactl and archived.
  https://github.com/grafana-cold-storage/grizzly (2026-06-05): superseded: by grafanactl.
- Dashboard schema v2 (dynamic dashboards) is GA; existing dashboards migrate on open.
  https://grafana.com/whats-new/2026-04-08-dynamic-dashboards-is-now-generally-available (2026-04-08): confirmed.
- dashboard-linter only supports Prometheus-datasource dashboards.
  https://github.com/grafana/dashboard-linter (2026-10-07): confirmed.
- Grafana can be provisioned declaratively with Nix.
  https://wiki.nixos.org/wiki/Grafana (undated): confirmed (general).
- Grafana best-practices page covers RED and USE and says design should reflect service hierarchy; discusses units, thresholds and consistency generally.
  https://grafana.com/docs/grafana/latest/visualizations/dashboards/build-dashboards/best-practices (undated): confirmed.
- "Place critical KPIs top-left" is Grafana guidance.
  same (undated): unconfirmed (page only mentions top-left for the info icon).
- Medium walkthrough: Claude via MCP builds an Apache dashboard from one prompt.
  https://medium.com/@ankitsaxena13579/bringing-generative-ai-to-observability-integrating-claude-ai-with-grafana-mcp-server-c741f46906c6 (2025-08-19): confirmed (demo only, no failure modes).
- mcp.directory guide: a skill builds dashboards from prompts, ten example dashboards.
  https://mcp.directory/blog/claude-grafana-dashboards-skill-guide (2026-06-24): confirmed (output claims are the site's own).
- No Catppuccin Grafana theme exists in the catppuccin org (362 repos) or its ports list.
  https://api.github.com/orgs/catppuccin/repos (2026-10-17): confirmed.
- GitHub repo search for Catppuccin + Grafana returns 0 results.
  https://api.github.com/search/repositories (2026-10-17): unconfirmed (code search not run).
- Catppuccin `palette.json` holds latte, frappe, macchiato, mocha hex values (e.g. mocha mauve `#cba6f7`).
  https://github.com/catppuccin/palette (2026-03-21 (v1.8.0)): confirmed.
- theme.park Grafana themes are deprecated, no Catppuccin variant.
  https://docs.theme-park.dev/themes/grafana (undated): confirmed.
- Latest Grafana is v13.2.4.
  https://github.com/grafana/grafana/releases/tag/v13.2.4 (2026-10-13): confirmed.
- Grafana 12 added experimental themes (Sapphire dusk, Tron, Gilded grove, Gloom, Desert bloom), chosen under Change theme.
  https://grafana.com/whats-new/2025-04-11-introducing-experimental-themes (2025-04-11): confirmed.
- Experimental themes need the `grafanaconThemes` feature toggle.
  https://grafana.com/docs/grafana/latest/administration/user-management/user-preferences/ (undated): contradicted: toggle absent from v13.2.4 source; themes gated by `allowedExtras` (unknown trigger).
- Server default theme is `default_theme` (dark, light, system) under `[users]`.
  https://grafana.com/docs/grafana/latest/setup-grafana/configure-grafana/ (undated): confirmed.
- Grafana has no custom CSS or custom-theme config option.
  same (undated): confirmed (absence).
- Panel colour schemes: single, shades, from thresholds, classic palette (incl. by series name), continuous by value.
  https://grafana.com/docs/grafana/latest/visualizations/panels-visualizations/configure-standard-options (undated): confirmed.
- Field overrides can set standard options on matched fields.
  https://grafana.com/docs/grafana/latest/visualizations/panels-visualizations/configure-overrides/ (undated): confirmed (colour-in-override not shown).
- Grafana 13 has experimental `panelStyleActions` to copy styles between panels.
  https://grafana.com/blog/grafana-13-release-all-the-latest-features (undated): confirmed.
- Astro Theme plugin (Astro UXDS CSS overrides) is stale since 2025-03.
  https://github.com/RocketCommunicationsInc/grafana-theme (2025-03-24): confirmed (stale).
- Boom Theme plugin is archived and deprecated.
  https://github.com/yesoreyeram/yesoreyeram-boomtheme-panel (2023-12-14): confirmed.

## Gaps

- **Failure-mode write-ups:** no dated post-mortems on LLMs hallucinating metric names, emitting invalid JSON or picking wrong units. Nobody has written up a render-feedback loop with `get_panel_image` either; it's possible, just undocumented.
- **Dashboard maturity model:** not covered by any source found.
- **Experimental theme gate in v13:** what sets `allowedExtras` wasn't traced.
- **API writes to file-provisioned dashboards:** not checked, which decides whether the official skill's push workflow fits caboodle's Nix-provisioned setup.
- **Image renderer:** `get_panel_image` needs the Grafana Image Renderer plugin; whether caboodle's monitoring host has it wasn't checked.
- **Plugin catalogue search:** the grafana.com plugin API rejected search, so no full catalogue sweep for palette or theme plugins.
