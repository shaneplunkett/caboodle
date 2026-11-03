package main

import (
	"strings"
	"testing"
	"time"
)

const mixedPost = `{
  "receiver": "linear",
  "status": "firing",
  "notification_reason": "some alerts resolved",
  "alerts": [
    {
      "status": "firing",
      "labels": {"alertname": "HostDiskFilling", "host": "cube", "severity": "critical"},
      "annotations": {"summary": "Disk on cube is 91% full", "condition": "Root disk above 85%."},
      "startsAt": "2026-11-03T09:36:46.5Z",
      "endsAt": "0001-01-01T00:00:00Z",
      "generatorURL": "https://prometheus.shaneplunkett.com/graph?g0.expr=up&g0.tab=1",
      "fingerprint": "003b0a0f7d3fa569"
    },
    {
      "status": "resolved",
      "labels": {"alertname": "HostDiskFilling", "host": "pve"},
      "annotations": {},
      "startsAt": "2026-11-03T08:00:00Z",
      "endsAt": "2026-11-03T09:00:00Z",
      "generatorURL": "",
      "fingerprint": "aaaa0a0f7d3fa569"
    }
  ]
}`

func TestParsePayloadGoesByEachAlertsOwnStatus(t *testing.T) {
	p, err := parsePayload(strings.NewReader(mixedPost))
	if err != nil {
		t.Fatal(err)
	}
	if p.NotificationReason != "some alerts resolved" {
		t.Errorf("reason = %q", p.NotificationReason)
	}
	if len(p.Alerts) != 2 {
		t.Fatalf("got %d alerts", len(p.Alerts))
	}
	first, second := p.Alerts[0], p.Alerts[1]
	if first.resolved() {
		t.Error("first alert is firing, whatever the post says")
	}
	if !second.resolved() {
		t.Error("second alert resolved, whatever the post says")
	}
	if first.name() != "HostDiskFilling" || first.Fingerprint != "003b0a0f7d3fa569" {
		t.Errorf("first = %+v", first)
	}
	if want := time.Date(2026, 11, 3, 9, 36, 46, 500_000_000, time.UTC); !first.StartsAt.Equal(want) {
		t.Errorf("startsAt = %v", first.StartsAt)
	}
	if !first.EndsAt.IsZero() {
		t.Errorf("a firing alert's endsAt is the zero time, got %v", first.EndsAt)
	}
}

func TestParsePayloadRefusesWhatItCantIdentify(t *testing.T) {
	for name, body := range map[string]string{
		"not json":       `{"alerts": [`,
		"no fingerprint": `{"alerts": [{"status": "firing", "labels": {"alertname": "A"}}]}`,
		"no alertname":   `{"alerts": [{"status": "firing", "fingerprint": "abc"}]}`,
	} {
		if _, err := parsePayload(strings.NewReader(body)); err == nil {
			t.Errorf("%s: wanted an error", name)
		}
	}
}

func TestWhereFallsThroughHostNodeGroupThenHomelab(t *testing.T) {
	tests := []struct {
		labels map[string]string
		want   string
	}{
		{map[string]string{"host": "cube", "node": "n", "group": "g"}, "cube"},
		{map[string]string{"node": "n", "group": "g"}, "n"},
		{map[string]string{"group": "g"}, "g"},
		{map[string]string{}, "homelab"},
	}
	for _, tt := range tests {
		if got := (alert{Labels: tt.labels}).where(); got != tt.want {
			t.Errorf("where(%v) = %q, want %q", tt.labels, got, tt.want)
		}
	}
}

func TestIdentityURLEscapesTheAlertname(t *testing.T) {
	a := alert{Labels: map[string]string{"alertname": "Disk Filling"}, Fingerprint: "abc123"}
	want := "https://prometheus.shaneplunkett.com/alerts?search=Disk+Filling&fingerprint=abc123"
	if got := a.identityURL("https://prometheus.shaneplunkett.com/alerts"); got != want {
		t.Errorf("got %q", got)
	}
}
