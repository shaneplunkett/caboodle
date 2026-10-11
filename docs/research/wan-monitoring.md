# WAN and network monitoring

Research for two goals. First, hard, timestamped evidence for the Lightning Broadband fault ticket, which covers bursts of latency, loss and dropouts, mostly 2am to 7am, plus low upload. Second, WAN monitoring that gets set up once and then left alone.

## Recommendation

**Who's who on the line.** Lightning is the retailer. It says it doesn't run its own network and sells over [Lynham Networks](https://lightningbroadband.com.au/help-centre/), which now trades as [Neoloop, a Superloop company](https://lynhamnetworks.au/). The first hop, 103.247.3.44, belongs to neither. It sits in [Anycast Holdings' space, AS58511](https://rdap.apnic.net/ip/103.247.3.44), and Anycast Access (AS132072) is [Lightning's only BGP upstream](https://stat.ripe.net/AS136000). The ticket stays with Lightning. Expect the fix to need Neoloop or Anycast.

**Continuous probing.** Use `smokeping_prober`, not blackbox ICMP. Blackbox sends one echo per scrape, which misses short dropouts. Smokeping pings every second into counters and a histogram, so loss and latency can be worked out over any window afterwards. nixpkgs ships it as `services.prometheus.exporters.smokeping`.
- Feed it a config file through `extraFlags = [ "--config.file=..." ]` so each target gets a `role` label, then set `hosts = [ ]`.
- Use these targets, all at 1s:
  - the gateway's LAN address, `role=lan`
  - 103.247.3.44, `role=isp`
  - 1.1.1.1 and 8.8.8.8, `role=internet`
  - ping.ui.com, `role=internet`. It's the gateway's own monitor target.
- Swap the default buckets for ones packed into the 1 to 50 ms range, or turn on native histograms for that job.
- Scrape it every 15s.

**Cross-checks that dodge ICMP.** Add `tcp_connect` probes to 1.1.1.1:443 and DNS probes against 1.1.1.1 and 8.8.8.8 on the existing blackbox exporter. TCP and DNS answers aren't held back the way router ICMP is.

**Unpoller.** Use `services.prometheus.exporters.unpoller` with an API key.
- The nixpkgs module has no `api_key` option. Set `UP_UNIFI_CONTROLLER_0_API_KEY=file://<agenix path>` in the unit's environment instead.
- Set `verify_ssl = false` and leave `save_dpi` off.
- Scrape every 60s, because unpoller now polls the console in the background every 60s.
- Run at least 5.5.1. On UniFi Network 11, older versions drop `uplink_latency_seconds` and the speedtest series. nixpkgs pins 5.2.6 and the bump PR is still open.

**isp-status.** No unpoller version exports the 5-minute buckets. A systemd timer could fetch the endpoint with the API key every hour and log the JSON to the journal. Alloy already ships the journal to Loki, so the buckets land there with their own timestamps. That gives the ticket a second, vendor-side record.

**Speed tests.** Run them from a systemd timer on a wired host and write a textfile `.prom`, the same pattern as `unraid-smart` and `storagebox`. Avoid the scrape-triggered exporter.
- Pin one Melbourne server. Run every 3 to 4 hours at fixed minutes, including one or two inside the 2am to 7am window.
- Export a `last_run_timestamp` so the latency alerts can skip the minutes a test is saturating the link.
- Treat the gateway's own speedtest, through unpoller, as a cross-check only.

**Syslog.** In UniFi Network, go to CyberSecure, Traffic Logging, Activity Logging (Syslog), and send to a SIEM server on a high UDP port on `monitoring`.
- Add a monitoring-only `.alloy` file in `/etc/alloy` with `loki.source.syslog`: `protocol = "udp"`, `syslog_format = "rfc3164"`, and a `job="unifi"` label.
- Use receive time for timestamps.
- Turn on the Internet and System categories. Hold off on Security and firewall until you know how much they send.

**MTR.** Run `services.mtr-exporter` against 103.247.3.44 and 1.1.1.1 every 60s with `-n`. Path changes and per-hop loss then live in Prometheus.
- For text reports the ISP can read, add a systemd timer that runs `mtr -n -r -w -b -z -c 60` to both targets every 10 minutes from 01:00 to 08:00 and logs the output to the journal, which Alloy ships to Loki.
- Triggering mtr from Alertmanager is optional. Alerts fire too late for drops that only last a few seconds.

**Alerts.** Add three Prometheus rules on recording rules, using the repo's existing JSON rule shape: `WanPacketLoss`, `WanLatencyHigh` and `WanDown`. Each one checks the gateway baseline, so local trouble doesn't page as ISP trouble. The rule shapes are in [question 6](#6-other-additions).

**Evidence workflow.**
- Ask Lightning, in writing, to log the fault as a complaint. That starts the [Complaints Handling Standard](https://www.legislation.gov.au/F2018L00727/latest/text) clock.
- After each bad night, export a pack. It holds the loss and latency graphs for each target with the timezone stated, the event table, the mtr reports from the window, the UniFi Internet-category events and PPPoE lines from Loki, and the isp-status JSON.
- Both Prometheus and Loki keep 30 days, so export as you go.

## 1. Continuous latency, loss and jitter

### Blackbox ICMP vs smokeping_prober

- The blackbox `icmp` prober has no packet-count option. The [config reference](https://github.com/prometheus/blackbox_exporter/blob/master/CONFIGURATION.md#icmp_probe) lists only protocol, source, DF bit, payload size and TTL. The [prober](https://github.com/prometheus/blackbox_exporter/blob/master/prober/icmp.go) sends a single echo for each probe. At a 15s scrape that's four samples a minute, each a pass or a fail. A 5-second dropout can land between them.
- [smokeping_prober](https://github.com/SuperQ/smokeping_prober#readme) pings each host every 1s by default. It exports `smokeping_requests_total` and the histogram `smokeping_response_duration_seconds`. Loss over any window is `1 - increase(..._count) / increase(requests_total)`, which is the [upstream example rule](https://github.com/SuperQ/smokeping_prober/blob/master/example-rules.yml). Counters keep every ping, so the scrape interval only limits how finely you can slice windows. It doesn't cause missed events.
- Latest is v0.12.0, the same version nixpkgs has. v0.11.0 added custom labels per target, v0.8.0 config reload, and v0.7.0 native histograms and source IP ([CHANGELOG](https://github.com/SuperQ/smokeping_prober/blob/master/CHANGELOG.md)). The config file supports `interval`, `network` (ip4 or ip6), `protocol` (icmp or udp), `size`, `source`, `tos` and `labels` ([config.go](https://github.com/SuperQ/smokeping_prober/blob/master/config/config.go)).
- The alternative is [czerwonk/ping_exporter](https://github.com/czerwonk/ping_exporter), in nixpkgs as `services.prometheus.exporters.ping`. It exports rolling-window gauges: `ping_rtt_mean_seconds`, `ping_rtt_std_deviation_seconds` and `ping_loss_ratio`. The stddev gauge is handy as a ready-made jitter figure. But gauges only show the window at scrape time, which makes them weaker evidence than smokeping's counters.

**Jitter.** Smokeping records the latency distribution, not the gap between consecutive packets, so jitter comes out as spread: `histogram_quantile(0.9) - histogram_quantile(0.5)` over the window. That's good enough to show "latency went from steady 5 ms to a 5 to 300 ms smear at 03:10". It isn't RFC 3550 interarrival jitter.

**Buckets.** The default buckets double from 50 µs to 26 s ([module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/prometheus/exporters/smokeping.nix)), so the 3 to 25 ms range gets only three buckets. Pass a denser `buckets` list. The other route is to set `scrape_native_histograms: true` on the job ([Prometheus config](https://prometheus.io/docs/prometheus/latest/configuration/configuration/), default false), which picks up the native histogram the prober already exposes.

### nixpkgs module

[`services.prometheus.exporters.smokeping`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/prometheus/exporters/smokeping.nix) has `hosts` (required, no default), `pingInterval` (1s), `buckets`, `telemetryPath` and `extraFlags`. It grants `CAP_NET_RAW`, runs `--privileged`, and listens on port 9374. There's no config-file option, so pass `--config.file` through `extraFlags`. The blackbox module also grants `CAP_NET_RAW` ([blackbox.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/prometheus/exporters/blackbox.nix)).

### Targets

- **Gateway LAN address.** The LAN baseline. Loss here means the host, the cabling or the gateway itself, and it rules out the ISP.
- **103.247.3.44, the first hop.** Where the trouble starts. Weak evidence on its own, see below.
- **1.1.1.1 and 8.8.8.8.** Anycast endpoints the ISP knows. They show the effect end to end.
- **ping.ui.com.** What the gateway's own WAN monitor pings ([Ubiquiti](https://help.ui.com/hc/en-us/articles/360052548713-WAN-Failover-Load-Balancing-and-Port-Remapping-on-UniFi-Gateways)). It lines your data up with the UniFi Internet chart.
- **TCP 1.1.1.1:443, and DNS to 1.1.1.1 and 8.8.8.8.** Not ICMP, so routers don't deprioritise it.

**Rate limiting.** Routers answer ICMP aimed at themselves from the CPU, and control-plane policing rate-limits it. Cisco calls pinging a router to diagnose loss ["a common misconception"](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/control-plane-policing/217946-verify-control-plane-policing-violations.html) for that reason. So:
- Loss at 103.247.3.44 that doesn't carry through to 1.1.1.1 is probably policing, not a fault.
- Loss that appears at the hop and at everything beyond it, while the gateway stays clean, is the pattern that counts.
- Hold every probe at 1 pps. That stays under typical policer rates.

## 2. Unpoller

**Releases.** The latest is [v5.5.1, from 2026-10-07](https://github.com/unpoller/unpoller/releases/tag/v5.5.1). nixpkgs pins 5.2.6, and the [5.5.1 bump PR is open](https://github.com/NixOS/nixpkgs/pull/571902). 5.5.1 fixes [UniFi Network 11 dropping uplink and speedtest metrics](https://github.com/unpoller/unpoller/pull/1106). Network 11 stopped returning `stat` on `stat/device`, and older unpoller then skipped `uplink_latency_seconds` and `speedtest_*` along with it. Since [v3.2.0](https://github.com/unpoller/unpoller/releases/tag/v3.2.0), the Prometheus output serves scrapes from a background poll that runs every 60s by default. Scraping faster than that only re-reads the cache.

**API key.** Unpoller has supported API keys since [v2.14.0](https://github.com/unpoller/unpoller/releases/tag/v2.14.0) ([PR #791](https://github.com/unpoller/unpoller/pull/791)). The config key is `api_key` on the controller. It replaces user and pass ([example config](https://github.com/unpoller/unpoller/blob/master/examples/up.conf.example)). When it's set, the poller clears user and pass and sends `X-API-Key` ([input.go](https://github.com/unpoller/unpoller/blob/master/pkg/inputunifi/input.go)). `api_key` takes a `file://` prefix, the same as `pass`, so the secret never goes in the store.

**nixpkgs module.** The controller options in [unpoller.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/unpoller.nix) are `user`, `pass` (a path, rewritten to `file://`), `url`, `sites`, `save_ids`, `save_events`, `save_alarms`, `save_anomalies`, `save_dpi`, `save_sites`, `hash_pii` and `verify_ssl` (default true). There's no `api_key`. The submodule isn't freeform, so you can't add one either. A [PR to add it](https://github.com/NixOS/nixpkgs/pull/481430) closed unmerged in May 2026. The workaround is environment variables. Unpoller reads env vars with the `UP` prefix ([config.go](https://github.com/unpoller/unpoller/blob/master/pkg/poller/config.go)), and [cnfg](https://github.com/golift/cnfg) maps slice entries as `_0_`. So `UP_UNIFI_CONTROLLER_0_API_KEY=file:///run/agenix/unifi-api-key` on `systemd.services.prometheus-unpoller-exporter` should work, as long as the secret is readable by the exporter's user. The UniFi console's certificate is self-signed, so set `verify_ssl = false`.

**Useful metrics.** Namespace `unpoller_` ([collector.go](https://github.com/unpoller/unpoller/blob/master/pkg/promunifi/collector.go)).
- Gateway, `unpoller_device_*` ([usg.go](https://github.com/unpoller/unpoller/blob/master/pkg/promunifi/usg.go)):
  - `uplink_latency_seconds`, `uplink_speed_mbps`, `uplink_uptime_seconds`
  - `speedtest_download`, `speedtest_upload`, `speedtest_latency_seconds`, `speedtest_rundate_seconds`
  - `wan_receive_bytes_total`, `wan_transmit_bytes_total`, `wan_*_dropped_total`, `wan_*_errors_total`
  - `cpu_utilization_ratio`, `memory_utilization_ratio`, `temperature_celsius`
- WAN, `unpoller_wan_*` ([WAN_METRICS.md](https://github.com/unpoller/unifi/blob/master/WAN_METRICS.md)): `uptime_percentage`, `peak_upload_percent`, `provider_upload_kbps`, `service_provider_asn`, plus `wan_interface_state` ([wan_status.go](https://github.com/unpoller/unpoller/blob/master/pkg/promunifi/wan_status.go)).
- Clients, `unpoller_client_*` ([clients.go](https://github.com/unpoller/unpoller/blob/master/pkg/promunifi/clients.go)): per-client signal, rates and bytes.

**Cardinality.** Client series carry 14 labels, among them `ip`, `ap_name` and `sw_port`, plus 7 radio labels on Wi-Fi. A roam or an IP change starts a new series. With a home's worth of clients that's fine. DPI is the heavy one: four series per client per app, labelled by `category` and `application`. The nixpkgs option text warns that it ["impacts performance"](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/unpoller.nix). Leave it off. It does nothing for the ISP ticket.

**The isp-status gap.** Confirmed in source:
- The [unifi library](https://github.com/unpoller/unifi/blob/master/wan.go) defines `GetWANISPStatus` and the `WANISPStatusDetailed` type. That type covers `connection_warnings`, `uplink_status.statistics[]` (latency, latency_max, downtime and rx/tx rate averages) and `speedtest_historical`.
- Nothing in unpoller calls it.
- `wan_interface_state` comes from somewhere else entirely. `GetWANStatus` reads `/v2/api/site/<site>/wan/load-balancing/status`, or `/api/s/<site>/stat/status` on older consoles ([wan_status.go](https://github.com/unpoller/unifi/blob/master/wan_status.go), [types.go](https://github.com/unpoller/unifi/blob/master/types.go)). So unpoller exports nothing from isp-status, not even the state metric.
- Searching unpoller and unifi for isp-status, packet loss and uplink statistics turns up no open issue or PR. The nearest is the merged [WAN metrics PR #925](https://github.com/unpoller/unpoller/pull/925), which added config and uptime metrics and stopped there.
- A feature request upstream is reasonable. The library already parses the data.

**Unpoller to Loki.** The module can also push events, alarms and IDS hits to Loki through its own `loki` output, using `save_events`, `save_alarms` and `save_ids`. That's polled, though. Syslog (question 4) is push and also carries device logs, so I'd use syslog.

## 3. Scheduled speed tests

**Options in nixpkgs:**
- `services.prometheus.exporters.speedtest` runs [podocarp/speedtest_exporter](https://github.com/podocarp/speedtest_exporter), a fork of danopstech's. It's built on the unofficial [showwin/speedtest-go](https://github.com/showwin/speedtest-go) client, not the Ookla binary. It runs a whole test on every scrape and locks while it does. The README suggests a 60m scrape interval with a 60s timeout. The module exposes `serverID` and `serverFallback` ([speedtest.nix](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/monitoring/prometheus/exporters/speedtest.nix)).
- `speedtest-go` has `--server`, `--json` and `--no-upload` ([README](https://github.com/showwin/speedtest-go)).
- `ookla-speedtest` is the official CLI and is unfree. `librespeed-cli` and `iperf3` are also packaged. nixpkgs has no iperf3 or librespeed exporter.

**Why a timer beats the scrape-triggered exporter:**
- A one-hour scrape interval means Prometheus marks the series stale after 5 minutes, so graphs need `last_over_time`.
- The scrape interval can't fix which minute the test runs.
- A systemd timer writing a textfile `.prom` gives a fixed time and a pinned server. It also gives a `speedtest_last_run_timestamp_seconds` the alerts can use to mask the test window.

**Downsides:**
- **Bandwidth.** One 10 s pass at 500 Mbps moves about 625 MB each way, so roughly 1.2 GB per test. Every 3 hours that's about 10 GB a day. Lightning plans are [unlimited](https://lightningbroadband.com.au/help-centre/).
- **It skews latency.** Saturating the link pushes up latency on every probe while it runs. Mask those minutes in alerts and annotate them in Grafana.
- **Server choice.** Different servers give different answers. Pick one in Melbourne and keep it. Better still, ask Lightning which server they accept. The ticket then argues with their own yardstick.
- **Ookla licence.** The [CLI EULA](https://www.speedtest.net/about/eula) grants "personal, non-commercial use on a single personal computer". It bans use "on any router, modem, or other non-personal computer device" and making it available "on a network where it is capable of being accessed by more than one device". A homelab server is a grey area. The upside of the CLI is a speedtest.net result URL, which ISP support staff recognise.

**Is the gateway's own speedtest enough?** No. Treat it as a cross-check. Unpoller exports the last result and its run date, so you control neither the schedule nor the server. The gateway can also be the bottleneck. Ubiquiti says Threat Management and Smart Queues can [cut throughput by up to 30%](https://help.ui.com/hc/en-us/articles/6949005136919-Optimizing-Wired-Network-Speeds), and that PPPoE is "very CPU-intensive". Lightning delivers static IPs [over PPPoE](https://lightningbroadband.com.au/help-centre/). So for the low upload, plot gateway `cpu_utilization_ratio` across a test before blaming the line.

## 4. UniFi syslog and SIEM to Loki

**Where to set it.** The UniFi Network UI has two places, and they send different things.
- Ubiquiti's [SIEM article](https://help.ui.com/hc/en-us/articles/33349041044119-UniFi-System-Logs-SIEM-Integration) says *Integration > System Logging / SIEM*. You select SIEM Server, choose categories, and enter an IP and port.
- The [support-files article](https://help.ui.com/hc/en-us/articles/360049956374-Getting-Support-Files-and-Logs) uses *Settings > CyberSecure > Traffic Logging > Activity Logging (Syslog)*.
- On the community forum, which is a secondary source, users report that Control Plane, Integrations only sends UniFi OS console events such as admin logins ([thread](https://community.ui.com/questions/Confusion-on-the-different-areas-menus-to-configure-SIEM-Syslog-exporting/b679f0ad-3bca-476e-a01d-6e8f8f70f8bf)). CyberSecure, Traffic Logging, Activity Logging carries the whole Network app stream, plus raw device logs that you can't switch off.
- Use the CyberSecure one.

**What it sends.**
- Ubiquiti says all exported events use CEF: `CEF:0|Ubiquiti|UniFi Network|<ver>|<id>|<name>|<sev>|<extensions>`, with `UNIFI*` extension keys ([SIEM article](https://help.ui.com/hc/en-us/articles/33349041044119-UniFi-System-Logs-SIEM-Integration)).
- The categories are Monitoring, Internet, Power, Security and System. The **Internet** category covers "WAN Failover, High Latency Detected, Packet Loss Detected". That's the gateway's own timestamped verdict on each event, which makes it good ticket material.
- Security covers firewall blocks, honeypot and IPS.
- Mixed into the same stream are non-CEF device lines: kernel and iptables-style firewall logs, dnsmasq DHCP, and presumably pppd. Sources for this are forum posts, all secondary ([thread](https://community.ui.com/questions/bf3cfc6d-e59f-4050-a21c-81576b32ac6e)).
- Real samples show a BSD-syslog header, `Jul 17 10:51:14 HOST CEF:0|Ubiquiti|UniFi Network|10.4.57|400|WiFi Client Connected|...` ([Wazuh samples](https://github.com/wazuh/integrations/blob/main/integrations/unifi_controller/log_samples.txt), secondary).
- Transport is UDP syslog. Users say so, and I found no Ubiquiti page that names the transport. A [forum post](https://community.ui.com/questions/Syslog-format-change-is-undocumented-in-OS-Release-5-0-16-Breaks-SIEM-Servers/621d3860-06fc-4b78-8b26-94e6bffcabf9) shows the dnsmasq line format changing in UniFi OS 5.0.16 without notice. Keep parsing loose.

**Alloy.** [`loki.source.syslog`](https://grafana.com/docs/alloy/latest/reference/components/loki/loki.source.syslog/):
- `listener` takes `address`, `protocol` (`tcp` by default, so set `udp`), `syslog_format` (`rfc5424` by default, or `rfc3164` or `raw`), `labels`, `use_incoming_timestamp`, `rfc3164_default_to_current_year`, `max_message_length` (8192) and `udp_queue_size` (10). The pinned Alloy, 1.17.1, has all of these.
- RFC3164 has no year and no timezone. Leave `use_incoming_timestamp` off and use receive time, which is accurate to well under a second over the LAN. Some CEF events also carry `UNIFIutcTime`.
- `raw` is experimental and needs `--stability.level=experimental` ([CLI](https://grafana.com/docs/alloy/latest/reference/cli/run/)), through `services.alloy.extraFlags`. Start with `rfc3164`. If the parser splits `CEF:0|...` into app name `CEF` and a mangled message, switch to `raw` and parse with `loki.process`.
- `__syslog_*` labels vanish unless you relabel them. Keep only `__syslog_message_hostname`, and maybe severity.
- Pull the CEF `Name` and `UNIFIcategory` out with `stage.regex`. Only promote low-cardinality fields like category to labels.
- Alloy runs on every host from the shared `config.alloy`. The NixOS module's `configPath` defaults to the `/etc/alloy` directory, and Alloy loads every `*.alloy` file in a directory as one config ([CLI docs](https://grafana.com/docs/alloy/latest/reference/cli/run/)). So the monitoring host can add `environment.etc."alloy/unifi.alloy"` that forwards to the existing `loki.write.monitoring`, and open one UDP port.

```alloy
loki.source.syslog "unifi" {
	listener {
		address       = "0.0.0.0:5514"
		protocol      = "udp"
		syslog_format = "rfc3164"
		labels        = {job = "unifi"}
	}
	relabel_rules = loki.relabel.unifi.rules
	forward_to    = [loki.process.unifi.receiver]
}
```

## 5. Evidence that moves an Australian ISP

**Who to aim at.**
- Lightning is the retailer on [Lynham Networks](https://lightningbroadband.com.au/help-centre/), which [trades as Neoloop under Superloop](https://lynhamnetworks.au/).
- [Superloop finished buying Lightning on 29 May 2026](https://www.superloop.com/blog/superloop-upgrades-fy26-guidance-and-launches-supercharge29-at-investor-day-2026). The ACCC notes that both run [local access lines they control](https://www.accc.gov.au/by-industry/telecommunications-and-internet/superfast-fixed-line-broadband-networks-regulation/superloop-joint-functional-separation-undertaking). It's not NBN.
- Lightning's [network status page](https://lightningbroadband.com.au/network-status) sends carrier outages to Neoloop. It lists scheduled maintenance by suburb, often from 23:00 to 05:00. Check every bad night against it, and against [status.neoloop.com.au](https://status.neoloop.com.au/), before you file.
- The first hop is in Anycast's AS58511 range. [Swoop bought Anycast in April 2020](https://swoop.com.au/wp-content/uploads/2021/07/SWOOP-PROSPECTUS.pdf).
- Lightning uses PPPoE, so 103.247.3.44 is probably the PPPoE peer, the BNG. Layer-3 tools can't tell the Neoloop access fibre from the BNG apart. Say so in the ticket, and ask them to check the ONT optical levels, port errors and BNG session logs for your times.

**The rules that apply.**
- Under the [Complaints Handling Standard](https://www.legislation.gov.au/F2018L00727/latest/text), a call "to report a fault or service difficulty" is **not** a complaint "unless a consumer advises that they want that call treated as a complaint".
- Once it is a complaint, the current text (compiled 1 January 2026) requires an acknowledgement and a unique reference within 2 working days for written complaints. A proposed resolution is due within 10 working days, and implementation within 5 working days after you accept it.
- If that stalls, go to the TIO. It refers the complaint back to the provider with a 10-working-day deadline. Skipping the provider adds 5 days ([TIO process](https://www.tio.com.au/how-it-works/our-process)).
- For internet faults the TIO tells you to ["write down when issues happened and how long they lasted"](https://www.tio.com.au/common-issues/faults/internet-faults) and to follow the provider's steps, such as a speed test or swapping the modem. It weighs "who is responsible for the fault and where it is located" and "if the quality of the service has changed".
- The TCP Code matters less here. The ACMA found it deficient and is [consulting on a replacement standard](https://www.acma.gov.au/consultations/2026-09/proposal-make-telecommunications-consumer-protections-industry-standard) until 10 November 2026.
- No rule sets the format or length of the evidence. What follows is practice, not regulation.

**What a pack should hold:**
- An event table with start, end, duration, peak latency and loss for each target. Timestamps in local time with the UTC offset. Melbourne went to AEDT on 4 October 2026, so a month of data crosses the change.
- Graphs for each night showing gateway clean, the hop bad, and 1.1.1.1 bad at the same moments. That puts the fault "past my router" without anyone needing to trust you.
- mtr reports from inside an event, with `-n -b -z` so they show IPs and ASNs. Point out where loss starts *and carries through to the destination*. Loss at one middle hop only is ICMP policing, and a good NOC will say so ([Cisco](https://www.cisco.com/c/en/us/support/docs/quality-of-service-qos/control-plane-policing/217946-verify-control-plane-policing-violations.html)).
- UniFi syslog lines. Did the WAN port's link or the PPPoE session drop, or did the session stay up while packets died? A link drop points at the ONT or fibre. Packets dying on a live session points upstream.
- The gateway's own isp-status buckets and its "Packet Loss Detected" events. A second, vendor-side record.
- A wired test straight from the wall port, which Lightning's own help centre asks for, and speed tests against the server they nominate.
- Two to four weeks of nights. Export each week, since Prometheus and Loki keep 30 days.

**Triggering mtr automatically.**
- Alertmanager's [`webhook_config`](https://prometheus.io/docs/alerting/latest/configuration/#webhook_config) can POST to a local receiver. NixOS has `services.webhook` ([module](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/webhook.nix)) to run a script.
- The catch is lag. `for:`, then `group_wait`, then evaluation adds up to a minute or more, so the drop may be over before mtr starts. Fine for a sustained bad patch, useless for a 10-second drop.
- A scheduled mtr in the known window, plus mtr-exporter running all the time, catches more for less code.

## 6. Other additions

**DNS.** The blackbox `dns` module already exists. Point it at 1.1.1.1, 8.8.8.8 and the ISP's resolvers to get `probe_dns_lookup_time_seconds`. That separates "DNS is slow" from "the path is slow".

**IPv6.** AS136000 announces [2400:3740::/32](https://stat.ripe.net/AS136000), but I couldn't confirm that residential services get IPv6. If the WAN has a global v6 address, add an `ip6` target group in smokeping for 2606:4700:4700::1111. v6 often takes a different path, which helps tell "the access line" apart from "one router".

**mtr-exporter.** [mgumz/mtr-exporter](https://github.com/mgumz/mtr-exporter) is v0.7.0, the same as nixpkgs. The module is [`services.mtr-exporter`](https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/services/networking/mtr-exporter.nix), with `jobs` (name, address, schedule, flags) and default port 8080. Port 8080 may clash, so set `port`.
- It exports `mtr_report_loss`, `_avg`, `_wrst` and `_stdev` per hop, with `hop=first|intermediate|last`, plus `mtr_report_path_id` for spotting route changes.
- Schedules accept `@every 60s ~10s` jitter. mtr bursts ICMP, so the jitter helps against rate limits.
- Gotcha: the module sets `CapabilityBoundingSet = [ "" ]` and `DynamicUser`. mtr-packet falls back to unprivileged ICMP datagram sockets ([probe_unix.c](https://github.com/traviscross/mtr/blob/master/packet/probe_unix.c)), which needs `net.ipv4.ping_group_range` to cover the service's group. nixpkgs has no NixOS test for this module. Check it actually reports hops on first deploy.

**Alert rules**, as starting points. Tune them after a week of baseline.

```yaml
- record: target:smokeping_loss:ratio5m
  expr: 1 - rate(smokeping_response_duration_seconds_count[5m]) / rate(smokeping_requests_total[5m])
- record: target:smokeping_rtt:p90_5m
  expr: histogram_quantile(0.9, sum by (host, role, le) (rate(smokeping_response_duration_seconds_bucket[5m])))

- alert: WanPacketLoss
  expr: max(target:smokeping_loss:ratio5m{role="internet"}) > 0.02 and on() max(target:smokeping_loss:ratio5m{role="lan"}) < 0.005
  for: 5m
- alert: WanLatencyHigh
  expr: min(target:smokeping_rtt:p90_5m{role="internet"}) > 0.05 unless on() (time() - speedtest_last_run_timestamp_seconds < 120)
  for: 10m
- alert: WanDown
  expr: min(target:smokeping_loss:ratio5m{role="internet"}) > 0.9
  for: 1m
```

`min` across the internet targets means *every* far target is bad, which rules out one anycast site having a bad night. The existing Alertmanager sends everything to Discord. A 3am page for every burst gets old fast, so give these `severity = "warning"` and lean on the data more than on the pings.

**Dashboards.**
- Unpoller's official set ([repo](https://github.com/unpoller/dashboards)): grafana.com [11313 USG Insights](https://grafana.com/grafana/dashboards/11313) for gateway and WAN, [11315 Client Insights](https://grafana.com/grafana/dashboards/11315), [11314 UAP Insights](https://grafana.com/grafana/dashboards/11314), [11311 Network Sites](https://grafana.com/grafana/dashboards/11311) and [11310 Client DPI](https://grafana.com/grafana/dashboards/11310). The grafana.com revisions date from 2023, so some panels may not match 5.x metric names.
- Smokeping: the prober repo bundles a [dashboard.json](https://github.com/SuperQ/smokeping_prober/blob/master/dashboard.json) with a heatmap, loss and latency per target. Its loss panel divides lifetime counters, so it shows loss since start rather than recent loss. Change it to `increase(...[$__rate_interval])`. [22471 SmokePing](https://grafana.com/grafana/dashboards/22471) is a third-party one with status, jitter and loss.
- mtr: [helpers/grafana-dashboard.json](https://github.com/mgumz/mtr-exporter/blob/master/helpers/grafana-dashboard.json).

**Optional.** RIPE Atlas gives outside measurements an ISP can't wave away. nixpkgs has `ripe-atlas-tools` but no software-probe module, so that one's a container job if you ever want it.

## Open questions and things I couldn't verify

- Whether 103.247.3.44 is the PPPoE peer, and who runs it, Anycast or Neoloop on Anycast addressing. RDAP and BGP only show address ownership. BGP data could also change as Superloop moves Lightning across.
- Whether the WAN actually uses PPPoE here. The help centre says static IPs come over PPPoE, and I didn't look at the gateway.
- Which UniFi Network version the console runs. On 11.x you need unpoller 5.5.1 before you get uplink latency and speedtest series.
- Whether the UniFi API key can read `/proxy/network/v2/.../isp-status`. Unpoller sends `X-API-Key` on v2 calls, but I didn't test this endpoint.
- The UniFi syslog transport and exact line format. No Ubiquiti page names UDP or the header format. Capture a few datagrams before you finalise the Alloy parser, and check how `rfc3164` handles `CEF:0|`.
- The `UP_UNIFI_CONTROLLER_0_API_KEY` mapping comes from reading cnfg's naming rules, not from a test. Check the startup log line `=> API Key: true`.
- Whether residential Lightning services get IPv6.
- Whether mtr-exporter works under the module's sandboxing without changes.
