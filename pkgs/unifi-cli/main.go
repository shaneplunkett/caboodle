// unifi — read-only CLI for Shane's UniFi Cloud Gateway Max.
//
// Auth: X-API-KEY header (official UniFi API key, generated in the UniFi
// Network UI → Control Plane → Integrations → API Keys). Controller URL +
// key are loaded by the nix home-manager wrapper from env vars, so this
// binary just trusts os.Getenv.
//
// Surface is intentionally tight: 10 read-only verbs. Writes are
// deliberately omitted — if Vex needs to mutate config she can SSH into
// the gateway or use the UI. JSON to stdout by default (jq-friendly);
// --pretty for human-readable indentation. Errors go to stderr.
package main

import (
	"context"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/urfave/cli/v3"
)

type config struct {
	controllerURL string
	apiKey        string
	site          string
	timeout       time.Duration
	pretty        bool
	client        *http.Client
}

func loadConfig(cmd *cli.Command) *config {
	c := &config{
		controllerURL: strings.TrimRight(envOr("UNIFI_CONTROLLER_URL", "https://192.168.1.1"), "/"),
		apiKey:        os.Getenv("UNIFI_API_KEY"),
		site:          envOr("UNIFI_SITE", "default"),
		timeout:       parseDurationOr("UNIFI_TIMEOUT", 10*time.Second),
		pretty:        cmd.Bool("pretty"),
	}
	c.client = &http.Client{
		Timeout: c.timeout,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, //nolint:gosec — UniFi controllers use self-signed certs by default
		},
	}
	return c
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func parseDurationOr(k string, def time.Duration) time.Duration {
	v := os.Getenv(k)
	if v == "" {
		return def
	}
	if d, err := time.ParseDuration(v); err == nil {
		return d
	}
	return def
}

func (c *config) request(ctx context.Context, method, path string, body io.Reader) ([]byte, error) {
	if c.apiKey == "" {
		fmt.Fprintln(os.Stderr, "unifi: UNIFI_API_KEY is unset. Add an entry named 'Unifi API Key' in Bitwarden with the API key as the password, then `rbw sync`.")
		os.Exit(3)
	}
	req, err := http.NewRequestWithContext(ctx, method, c.controllerURL+path, body)
	if err != nil {
		return nil, err
	}
	req.Header.Set("X-API-KEY", c.apiKey)
	req.Header.Set("Accept", "application/json")
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}

	resp, err := c.client.Do(req)
	if err != nil {
		fmt.Fprintf(os.Stderr, "unifi: cannot reach controller at %s: %v\n", c.controllerURL, err)
		os.Exit(4)
	}
	defer resp.Body.Close()

	data, _ := io.ReadAll(resp.Body)

	switch {
	case resp.StatusCode == 401:
		fmt.Fprintln(os.Stderr, "unifi: 401 Unauthorized — API key is missing, invalid, or revoked.")
		os.Exit(5)
	case resp.StatusCode == 403:
		fmt.Fprintln(os.Stderr, "unifi: 403 Forbidden — API key lacks permission for this endpoint.")
		os.Exit(5)
	case resp.StatusCode >= 400:
		snippet := string(data)
		if len(snippet) > 300 {
			snippet = snippet[:300]
		}
		fmt.Fprintf(os.Stderr, "unifi: HTTP %d from %s: %s\n", resp.StatusCode, path, snippet)
		os.Exit(6)
	}

	return data, nil
}

// legacyData unwraps the {"meta":{"rc":"ok"},"data":[...]} envelope used by
// the /proxy/network/api/... endpoints and returns the data slice as a raw
// json.RawMessage that callers can unmarshal into the right shape.
func (c *config) legacyData(ctx context.Context, path string) (json.RawMessage, error) {
	body, err := c.request(ctx, "GET", path, nil)
	if err != nil {
		return nil, err
	}
	var envelope struct {
		Meta json.RawMessage `json:"meta"`
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(body, &envelope); err != nil {
		fmt.Fprintf(os.Stderr, "unifi: non-JSON response from %s: %s\n", path, truncate(string(body), 300))
		os.Exit(6)
	}
	if len(envelope.Data) == 0 {
		return json.RawMessage("[]"), nil
	}
	return envelope.Data, nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

func (c *config) emit(v any) error {
	enc := json.NewEncoder(os.Stdout)
	if c.pretty {
		enc.SetIndent("", "  ")
	}
	enc.SetEscapeHTML(false)
	return enc.Encode(v)
}

// ============================================================================
// Subcommands
// ============================================================================

func statusCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)

	healthRaw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/health")
	var health []map[string]any
	_ = json.Unmarshal(healthRaw, &health)

	devicesRaw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/device")
	var devices []map[string]any
	_ = json.Unmarshal(devicesRaw, &devices)

	alarmsRaw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/list/alarm?archived=false")
	var alarms []map[string]any
	_ = json.Unmarshal(alarmsRaw, &alarms)

	bySub := map[string]map[string]any{}
	for _, h := range health {
		if s, ok := h["subsystem"].(string); ok {
			bySub[s] = h
		}
	}
	wan := bySub["wan"]
	lan := bySub["lan"]
	wlan := bySub["wlan"]
	www := bySub["www"]

	var gateway map[string]any
	for _, d := range devices {
		t, _ := d["type"].(string)
		model, _ := d["model"].(string)
		if t == "ugw" || t == "udm" || strings.HasPrefix(model, "UCG") {
			gateway = d
			break
		}
	}

	gw := map[string]any{}
	if gateway != nil {
		gw["name"] = gateway["name"]
		gw["model"] = gateway["model"]
		gw["version"] = gateway["version"]
		gw["uptime_seconds"] = gateway["uptime"]
		gw["state"] = gateway["state"]
		gw["temperature_c"] = gateway["general_temperature"]
		if ss, ok := gateway["system-stats"].(map[string]any); ok {
			gw["cpu_percent"] = ss["cpu"]
			gw["mem_percent"] = ss["mem"]
		}
	}

	summary := map[string]any{
		"wan": map[string]any{
			"status":                   firstNonNil(wan, "status"),
			"isp_name":                 firstNonNil(wan, "isp_name"),
			"isp_organization":         firstNonNil(wan, "isp_organization"),
			"wan_ip":                   firstNonNil(wan, "wan_ip"),
			"gw_mac":                   firstNonNil(wan, "gw_mac"),
			"latency_ms":               firstNonNil(wan, "latency"),
			"uptime_seconds":           firstNonNil(wan, "uptime"),
			"drops":                    firstNonNil(wan, "drops"),
			"speedtest_rundate":        firstNonNil(wan, "speedtest_rundate"),
			"speedtest_ping_ms":        firstNonNil(wan, "speedtest_ping"),
			"speedtest_download_mbps":  firstNonNil(wan, "xput_down"),
			"speedtest_upload_mbps":    firstNonNil(wan, "xput_up"),
		},
		"internet": map[string]any{
			"status":     firstNonNil(www, "status"),
			"latency_ms": firstNonNil(www, "latency"),
			"drops":      firstNonNil(www, "drops"),
			"uptime":     firstNonNil(www, "uptime"),
		},
		"lan": map[string]any{
			"status":    firstNonNil(lan, "status"),
			"num_user":  firstNonNil(lan, "num_user"),
			"num_guest": firstNonNil(lan, "num_guest"),
			"num_iot":   firstNonNil(lan, "num_iot"),
		},
		"wlan": map[string]any{
			"status":    firstNonNil(wlan, "status"),
			"num_user":  firstNonNil(wlan, "num_user"),
			"num_guest": firstNonNil(wlan, "num_guest"),
		},
		"gateway":       gw,
		"device_count":  len(devices),
		"alarms_active": len(alarms),
	}
	return c.emit(summary)
}

func firstNonNil(m map[string]any, key string) any {
	if m == nil {
		return nil
	}
	return m[key]
}

func sitesCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	raw, _ := c.legacyData(ctx, "/proxy/network/api/self/sites")
	var data any
	_ = json.Unmarshal(raw, &data)
	return c.emit(data)
}

func devicesCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	raw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/device")
	if cmd.Bool("full") {
		var data any
		_ = json.Unmarshal(raw, &data)
		return c.emit(data)
	}

	var devices []map[string]any
	_ = json.Unmarshal(raw, &devices)

	macFilter := strings.ToLower(cmd.String("mac"))
	nameFilter := strings.ToLower(cmd.String("name"))

	rows := []map[string]any{}
	for _, d := range devices {
		if macFilter != "" && strings.ToLower(asString(d["mac"])) != macFilter {
			continue
		}
		if nameFilter != "" && strings.ToLower(asString(d["name"])) != nameFilter {
			continue
		}
		rows = append(rows, map[string]any{
			"name":           d["name"],
			"model":          d["model"],
			"type":           d["type"],
			"mac":            d["mac"],
			"ip":             d["ip"],
			"version":        d["version"],
			"state":          d["state"],
			"uptime_seconds": d["uptime"],
			"adopted":        d["adopted"],
			"temperature_c":  d["general_temperature"],
			"num_clients":    d["num_sta"],
		})
	}
	return c.emit(rows)
}

func clientsCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	endpoint := "sta"
	if cmd.Bool("all") {
		endpoint = "alluser"
	}
	raw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/"+endpoint)

	if cmd.Bool("full") {
		var data any
		_ = json.Unmarshal(raw, &data)
		return c.emit(data)
	}

	var clients []map[string]any
	_ = json.Unmarshal(raw, &clients)

	macFilter := strings.ToLower(cmd.String("mac"))
	wiredOnly := cmd.Bool("wired")
	wirelessOnly := cmd.Bool("wireless")

	rows := []map[string]any{}
	for _, cl := range clients {
		isWired, _ := cl["is_wired"].(bool)
		if macFilter != "" && strings.ToLower(asString(cl["mac"])) != macFilter {
			continue
		}
		if wiredOnly && !isWired {
			continue
		}
		if wirelessOnly && isWired {
			continue
		}
		hostname := cl["hostname"]
		if hostname == nil || hostname == "" {
			hostname = cl["name"]
		}
		rows = append(rows, map[string]any{
			"hostname":       hostname,
			"mac":            cl["mac"],
			"ip":             cl["ip"],
			"is_wired":       cl["is_wired"],
			"network":        cl["network"],
			"ap_mac":         cl["ap_mac"],
			"essid":          cl["essid"],
			"signal_dbm":     cl["signal"],
			"rx_bytes":       cl["rx_bytes"],
			"tx_bytes":       cl["tx_bytes"],
			"uptime_seconds": cl["uptime"],
			"first_seen":     cl["first_seen"],
			"last_seen":      cl["last_seen"],
			"manufacturer":   cl["oui"],
		})
	}
	return c.emit(rows)
}

func eventsCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	limit := cmd.Int("limit")
	minutes := cmd.Int("minutes")
	keyFilter := strings.ToUpper(cmd.String("key"))

	raw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/event")
	var events []map[string]any
	_ = json.Unmarshal(raw, &events)

	cutoffMs := int64(0)
	if minutes > 0 {
		cutoffMs = time.Now().Add(-time.Duration(minutes)*time.Minute).UnixMilli()
	}

	rows := []map[string]any{}
	for _, e := range events {
		if keyFilter != "" {
			k, _ := e["key"].(string)
			if !strings.Contains(strings.ToUpper(k), keyFilter) {
				continue
			}
		}
		if cutoffMs > 0 {
			if t, ok := e["time"].(float64); ok && int64(t) < cutoffMs {
				continue
			}
		}
		rows = append(rows, map[string]any{
			"time_ms":   e["time"],
			"datetime":  e["datetime"],
			"key":       e["key"],
			"subsystem": e["subsystem"],
			"msg":       e["msg"],
			"ap":        e["ap_name"],
			"user":      e["user"],
		})
		if len(rows) >= limit {
			break
		}
	}
	return c.emit(rows)
}

func alarmsCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	qs := "?archived=false"
	if cmd.Bool("include-archived") {
		qs = ""
	}
	raw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/list/alarm"+qs)
	var alarms []map[string]any
	_ = json.Unmarshal(raw, &alarms)

	rows := []map[string]any{}
	for _, a := range alarms {
		rows = append(rows, map[string]any{
			"time_ms":   a["time"],
			"datetime":  a["datetime"],
			"key":       a["key"],
			"subsystem": a["subsystem"],
			"msg":       a["msg"],
			"archived":  a["archived"],
		})
	}
	return c.emit(rows)
}

func networksCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	raw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/rest/networkconf")
	var networks []map[string]any
	_ = json.Unmarshal(raw, &networks)

	rows := []map[string]any{}
	for _, n := range networks {
		rows = append(rows, map[string]any{
			"name":         n["name"],
			"purpose":      n["purpose"],
			"vlan":         n["vlan"],
			"subnet":       n["ip_subnet"],
			"domain_name":  n["domain_name"],
			"dhcp_enabled": n["dhcpd_enabled"],
			"dhcp_start":   n["dhcpd_start"],
			"dhcp_stop":    n["dhcpd_stop"],
			"enabled":      n["enabled"],
		})
	}
	return c.emit(rows)
}

func wifiCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	raw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/rest/wlanconf")
	var wlans []map[string]any
	_ = json.Unmarshal(raw, &wlans)

	rows := []map[string]any{}
	for _, w := range wlans {
		rows = append(rows, map[string]any{
			"ssid":      w["name"],
			"enabled":   w["enabled"],
			"security":  w["security"],
			"wpa_mode":  w["wpa_mode"],
			"is_guest":  w["is_guest"],
			"hide_ssid": w["hide_ssid"],
			"vlan":      w["vlan"],
		})
	}
	return c.emit(rows)
}

func wanCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)
	healthRaw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/health")
	var health []map[string]any
	_ = json.Unmarshal(healthRaw, &health)

	wanBlocks := []map[string]any{}
	for _, h := range health {
		s, _ := h["subsystem"].(string)
		if s == "wan" || s == "www" || strings.HasPrefix(s, "wan") {
			wanBlocks = append(wanBlocks, h)
		}
	}

	devicesRaw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/device")
	var devices []map[string]any
	_ = json.Unmarshal(devicesRaw, &devices)

	var gateway map[string]any
	for _, d := range devices {
		t, _ := d["type"].(string)
		model, _ := d["model"].(string)
		if t == "ugw" || t == "udm" || strings.HasPrefix(model, "UCG") {
			gateway = d
			break
		}
	}

	uplinks := []map[string]any{}
	if gateway != nil {
		if ports, ok := gateway["port_table"].([]any); ok {
			for _, p := range ports {
				port, ok := p.(map[string]any)
				if !ok {
					continue
				}
				isUplink, _ := port["is_uplink"].(bool)
				ifname, _ := port["ifname"].(string)
				if !isUplink && !strings.HasPrefix(ifname, "wan") {
					continue
				}
				uplinks = append(uplinks, map[string]any{
					"ifname":      port["ifname"],
					"media":       port["media"],
					"speed":       port["speed"],
					"full_duplex": port["full_duplex"],
					"rx_bytes":    port["rx_bytes"],
					"tx_bytes":    port["tx_bytes"],
					"rx_errors":   port["rx_errors"],
					"tx_errors":   port["tx_errors"],
					"rx_dropped":  port["rx_dropped"],
					"tx_dropped":  port["tx_dropped"],
				})
			}
		}
	}

	return c.emit(map[string]any{
		"wan_subsystems": wanBlocks,
		"uplinks":        uplinks,
	})
}

func speedtestCmd(ctx context.Context, cmd *cli.Command) error {
	c := loadConfig(cmd)

	body := strings.NewReader(`{"cmd":"speedtest"}`)
	_, err := c.request(ctx, "POST", "/proxy/network/api/s/"+c.site+"/cmd/devmgr", body)
	if err != nil {
		return err
	}

	if cmd.Bool("no-wait") {
		return c.emit(map[string]any{"triggered": true})
	}

	deadline := time.Now().Add(75 * time.Second)
	var lastRundate any
	for time.Now().Before(deadline) {
		time.Sleep(3 * time.Second)
		healthRaw, _ := c.legacyData(ctx, "/proxy/network/api/s/"+c.site+"/stat/health")
		var health []map[string]any
		_ = json.Unmarshal(healthRaw, &health)
		for _, h := range health {
			if s, _ := h["subsystem"].(string); s == "wan" {
				rundate := h["speedtest_rundate"]
				if rundate != nil && rundate != "" && rundate != lastRundate {
					return c.emit(map[string]any{
						"speedtest_rundate": rundate,
						"ping_ms":           h["speedtest_ping"],
						"download_mbps":     h["xput_down"],
						"upload_mbps":       h["xput_up"],
						"status":            h["speedtest_status"],
					})
				}
				if lastRundate == nil {
					lastRundate = rundate
				}
			}
		}
	}
	fmt.Fprintln(os.Stderr, "unifi: speedtest did not finish within 75s — try `unifi status` later for the result.")
	os.Exit(7)
	return nil
}

func asString(v any) string {
	s, _ := v.(string)
	return s
}

// ============================================================================
// main / wiring
// ============================================================================

func main() {
	cmd := &cli.Command{
		Name:  "unifi",
		Usage: "Read-only CLI for the UniFi Cloud Gateway Max. JSON by default; --pretty for humans.",
		Flags: []cli.Flag{
			&cli.BoolFlag{Name: "pretty", Usage: "Pretty-print JSON output."},
		},
		Commands: []*cli.Command{
			{Name: "status", Usage: "Synthesised health: WAN, LAN, WLAN, gateway, alarms.", Action: statusCmd},
			{Name: "sites", Usage: "List UniFi sites.", Action: sitesCmd},
			{
				Name:  "devices",
				Usage: "List UniFi devices (gateway, APs, switches).",
				Flags: []cli.Flag{
					&cli.StringFlag{Name: "mac", Usage: "Filter to a single device by MAC."},
					&cli.StringFlag{Name: "name", Usage: "Filter to a single device by display name."},
					&cli.BoolFlag{Name: "full", Usage: "Emit the full device payload (large)."},
				},
				Action: devicesCmd,
			},
			{
				Name:  "clients",
				Usage: "List network clients. Default is active only.",
				Flags: []cli.Flag{
					&cli.BoolFlag{Name: "all", Usage: "Include historical/known clients."},
					&cli.StringFlag{Name: "mac", Usage: "Filter to a single client by MAC."},
					&cli.BoolFlag{Name: "wired", Usage: "Wired clients only."},
					&cli.BoolFlag{Name: "wireless", Usage: "Wireless clients only."},
					&cli.BoolFlag{Name: "full", Usage: "Emit the full client payload (large)."},
				},
				Action: clientsCmd,
			},
			{
				Name:  "events",
				Usage: "Recent controller events.",
				Flags: []cli.Flag{
					&cli.IntFlag{Name: "limit", Value: 50, Usage: "Max events to return."},
					&cli.IntFlag{Name: "minutes", Usage: "Only events within the last N minutes."},
					&cli.StringFlag{Name: "key", Usage: "Filter by event-key substring (e.g. WAN, WLAN, LAN_CONNECTED)."},
				},
				Action: eventsCmd,
			},
			{
				Name:  "alarms",
				Usage: "Active alarms (unarchived by default).",
				Flags: []cli.Flag{
					&cli.BoolFlag{Name: "include-archived", Usage: "Include archived alarms."},
				},
				Action: alarmsCmd,
			},
			{Name: "networks", Usage: "Configured LAN/VLAN networks.", Action: networksCmd},
			{Name: "wifi", Usage: "Configured WiFi networks (WLANs).", Action: wifiCmd},
			{Name: "wan", Usage: "WAN-side detail: subsystem health + uplink port stats.", Action: wanCmd},
			{
				Name:  "speedtest",
				Usage: "Trigger an internet speedtest from the gateway. Blocks until result lands (~30-60s).",
				Flags: []cli.Flag{
					&cli.BoolFlag{Name: "no-wait", Usage: "Fire-and-forget — don't wait for the result."},
				},
				Action: speedtestCmd,
			},
		},
	}

	if err := cmd.Run(context.Background(), os.Args); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
