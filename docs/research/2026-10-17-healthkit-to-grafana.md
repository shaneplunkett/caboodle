# Apple HealthKit data into Grafana

- **Question:** Getting my Apple HealthKit data off my Apple devices into some sort of data store and then presenting it via Grafana, or even going into Prometheus maybe? Grafana also lets you access it via MCP, which would be helpful. Chronic illness girly needs her data. Had jank OpenWearables stuff in the past that just sucked, so something better that our homelab can enable.
- **Researched:** 2026-10-17, deep

## Sub-questions

1. iOS-side export paths in 2026 (Health Auto Export, export.xml, Shortcuts, other apps) and iOS background-delivery limits: answered (Shortcuts and Heartbridge unchecked)
2. Whether a Mac on macOS 26 or later can read HealthKit directly, avoiding a phone app: answered
3. Self-hosted receivers and ingest projects: maintenance, NixOS packaging, backfill and dedup: answered (only the projects the report named)
4. Data store fit for irregular health samples plus Grafana: answered (no Postgres or TimescaleDB evidence found)
5. MCP access through the Grafana MCP and dedicated Apple Health MCP servers: answered

## Claims

Each claim, then its source, date and verdict.

- Health Auto Export (HAE) REST automations POST JSON or CSV to any endpoint.
  https://help.healthyapps.dev/en/health-auto-export/automations/rest-api (2026-08-23): confirmed.
- HAE background work typically has to finish within 30 seconds and is memory-limited.
  https://help.healthyapps.dev/en/health-auto-export/automations/rest-api (2026-08-23): confirmed.
- Health data can't be read while the iPhone is locked, so automations run only while it's unlocked.
  https://help.healthyapps.dev/en/health-auto-export/automations/rest-api (2026-08-23): confirmed (missing from the report).
- HAE MQTT automations publish JSON only.
  https://help.healthyapps.dev/en/health-auto-export/automations/mqtt (undated): confirmed.
- HAE automations can send GPX.
  HAE REST and MQTT docs (2026-08-23): unconfirmed: neither doc mentions GPX.
- HKObserverQuery and HKAnchoredObjectQuery support incremental sync, and the anchored query reports deleted samples.
  https://developer.apple.com/documentation/healthkit/hkanchoredobjectquery (undated): confirmed.
- Background delivery and BackgroundTasks are batched or not guaranteed.
  Apple background-delivery entitlement and BackgroundTasks docs (undated): unconfirmed: the fetched text doesn't say so.
- Low Power Mode suspends background tasks, and first syncs can take 15+ minutes.
  https://openwearables.io/docs/sdk/ios/troubleshooting (undated): confirmed.
- Claims about Shortcuts, Heartbridge and Health Exporter.
  report sources (undated): unconfirmed: not fetched.
- The HealthKit framework lists macOS 14.0+ and Mac Catalyst 17.0+.
  https://developer.apple.com/documentation/healthkit (undated): confirmed.
- HKObserverQuery lists macOS 13.0.
  https://developer.apple.com/documentation/healthkit/hkobserverquery (undated): unconfirmed: conflicts with the framework page's 14.0.
- A Mac can read the phone's HealthKit store directly.
  https://developer.apple.com/documentation/healthkit (undated): contradicted: Apple describes HealthKit as the central repository on iPhone and Apple Watch.
- ai-health-sync-ios runs a TLS server on the iPhone that a macOS CLI pulls from; it needs macOS 15+ and iOS 26.0+.
  https://github.com/mneves75/ai-health-sync-ios (2026-09-23 (push), v1.0.0 2026-08-19): confirmed; the report's "macOS agent reads HealthKit directly" is contradicted.
- HAE "Sync to Mac" moves metrics from the iPhone to a Mac through iCloud.
  https://help.healthyapps.dev/en/health-auto-export/sync-to-mac (2026-08-23): confirmed.
- macOS 26 adds HealthKit APIs or types.
  https://developer.apple.com/documentation/macos-release-notes/macos-26_6-release-notes (undated): unconfirmed: the release notes don't mention HealthKit.
- apple-health-ingester receives HAE pushes and writes to InfluxDB or a local file, and is actively maintained.
  https://github.com/irvinlim/apple-health-ingester (2025-02-06 (last commit, v0.5.0)): the targets are confirmed; "actively maintained" is contradicted.
- healthkit-to-influx-docker is active.
  https://github.com/fletchto99/healthkit-to-influx-docker (2023-01-24 (last push)): contradicted: the repo is archived.
- health-auto-export-server is Node.js and Grafana on MongoDB, with no license detected.
  https://github.com/HealthyApps/health-auto-export-server (2025-12-15 (last push)): confirmed for the stack; "actively maintained" is unconfirmed.
- apple-health-grafana does a one-shot import of export.zip into InfluxDB, not a live feed.
  https://github.com/k0rventen/apple-health-grafana (2026-05-28 (v0.7.0)): confirmed.
- Nixpkgs packages `influxdb` 1.12.2 (v1 line) and `influxdb3` 3.8.3.
  https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/in/influxdb/package.nix (undated): confirmed.
- Initial full syncs process large historical volumes, and memory should settle after the first sync.
  https://openwearables.io/docs/sdk/ios/troubleshooting (undated): confirmed.
- Apple sometimes merges historic samples, which creates deletions that dedup has to handle.
  https://support.mydatahelps.org/apple-healthkitv2-samples-export-format (undated): confirmed.
- The MyDataHelps export has `Device` and `InsertedDate` fields.
  https://support.mydatahelps.org/apple-healthkitv2-samples-export-format (undated): unconfirmed: not found on the page.
- Prometheus backfills from OpenMetrics blocks via promtool, without staleness markers.
  https://prometheus.io/docs/prometheus/latest/storage/ (undated): confirmed.
- Prometheus rejects samples older than the head's max time minus `out_of_order_time_window`.
  https://prometheus.io/docs/prometheus/latest/configuration/configuration/ (undated): confirmed.
- Prometheus retention defaults to 15 days, and its remote-write receiver is `--web.enable-remote-write-receiver`.
  https://prometheus.io/docs/prometheus/latest/storage/ (undated): confirmed.
- VictoriaMetrics imports JSON line, native, CSV and Prometheus exposition formats.
  https://docs.victoriametrics.com/victoriametrics/single-server-victoriametrics/ (undated): confirmed.
- VictoriaMetrics `-retentionPeriod` defaults to 31 days.
  https://docs.victoriametrics.com/victoriametrics/single-server-victoriametrics/ (undated): confirmed.
- InfluxDB 3 Core has a 72-hour retention ceiling.
  https://medium.com/@artemkhrenov/time-series-database-patterns-influxdb-and-timescaledb-for-analytics-32daf132297f (undated): superseded: an InfluxData blog post updated 2025-11-20 says historical writes and retention are uncapped, but a single query spans at most ~72h of data; Enterprise lifts that and is free for home use.
- InfluxDB shard-group duration matters for bulk backfill.
  https://docs.influxdata.com/influxdb/v1/concepts/schema_and_data_layout/ (undated): partly confirmed: the concept is documented, the backfill advice isn't.
- TimescaleDB and Postgres have TSBS benchmark support.
  MyDataHelps clinical-records page (undated): contradicted: that page makes no TSBS claim.
- Grafana bundles Prometheus, Loki and MySQL as core datasources.
  https://grafana.com/docs/grafana/latest/datasources/concepts (undated): confirmed.
- VictoriaMetrics needs memory tuning for slow inserts.
  VictoriaMetrics troubleshooting page (undated): unconfirmed: not fetched.
- mcp-grafana's SQL tools (`query_sql`, `list_sql_databases`, `list_sql_tables`, `describe_sql_table`) support PostgreSQL, MySQL, MSSQL, ClickHouse, Snowflake and Athena; they're off by default and enabled with `sql` in `--enabled-tools`.
  https://github.com/grafana/mcp-grafana (2026-10-07 (v2.0.2)): confirmed; the report called this unknown.
- `grafana_api_request` can POST to `/api/ds/query` unless `--disable-api` is set.
  https://github.com/grafana/mcp-grafana (2026-10-17): confirmed.
- apple-health-mcp reads export.xml or export.zip only, with no live HealthKit access.
  https://github.com/davidmosiah/apple-health-mcp (2026-08-29 (v0.7.4)): confirmed.

## Gaps

- Shortcuts and Heartbridge weren't checked as export paths.
- The macOS 26 HealthKit claims couldn't be checked against the Xcode wiki page, which was too large to fetch.
- No receiver that writes HAE pushes to VictoriaMetrics or PostgreSQL turned up, and the search covered only the projects the report named.
- The research found no Postgres or TimescaleDB evidence for health data.
- Nobody tested a live Grafana SQL query through the MCP.
- The Tavily report's `sources` array didn't match its own numbered references, so citations were mapped from its reference list.
