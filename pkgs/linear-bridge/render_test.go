package main

import (
	"strings"
	"testing"
	"time"
)

var (
	startsAt = time.Date(2026, 11, 3, 8, 0, 0, 0, time.UTC)
	endsAt   = time.Date(2026, 11, 3, 10, 14, 30, 0, time.UTC)
	firedNow = time.Date(2026, 11, 3, 9, 15, 0, 0, time.UTC)
)

const generator = "https://prometheus.shaneplunkett.com/graph?g0.expr=up&g0.tab=1"

func firing(annotations map[string]string) alert {
	return alert{
		Status:       "firing",
		Labels:       map[string]string{"alertname": "HostDiskFilling", "host": "cube"},
		Annotations:  annotations,
		StartsAt:     startsAt,
		GeneratorURL: generator,
		Fingerprint:  "003b0a0f7d3fa569",
	}
}

func finished(annotations map[string]string) alert {
	a := firing(annotations)
	a.Status = "resolved"
	a.EndsAt = endsAt
	return a
}

func TestViewLink(t *testing.T) {
	// 2026-11-03T07:00:00Z is 1793689200000 ms; endsAt+15m, 10:29:30Z, is 1793701770000 ms.
	tests := []struct {
		name  string
		alert alert
		want  string
	}{
		{
			"dashboard while firing runs to now",
			firing(map[string]string{"dashboard": "https://grafana.example/d/x"}),
			"[Dashboard](https://grafana.example/d/x?from=1793689200000&to=now)",
		},
		{
			"dashboard with a query appends with an ampersand",
			firing(map[string]string{"dashboard": "https://grafana.example/d/x?var-host=cube"}),
			"[Dashboard](https://grafana.example/d/x?var-host=cube&from=1793689200000&to=now)",
		},
		{
			"dashboard when resolved stops 15m after the end",
			finished(map[string]string{"dashboard": "https://grafana.example/d/x"}),
			"[Dashboard](https://grafana.example/d/x?from=1793689200000&to=1793701770000)",
		},
		{
			"graph while firing covers an hour before it started until now",
			firing(nil),
			"[Graph in Prometheus](https://prometheus.shaneplunkett.com/graph?g0.expr=up&g0.range_input=2h15m0s&g0.tab=graph)",
		},
		{
			"graph when resolved pins the end of the window",
			finished(nil),
			"[Graph in Prometheus](https://prometheus.shaneplunkett.com/graph?g0.end_input=2026-11-03T10%3A29%3A30Z&g0.expr=up&g0.range_input=3h30m0s&g0.tab=graph)",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := viewLink(tt.alert, firedNow); got != tt.want {
				t.Errorf("\n got %s\nwant %s", got, tt.want)
			}
		})
	}
}

func TestViewLinkIsEmptyWithNothingToLinkTo(t *testing.T) {
	a := firing(nil)
	a.GeneratorURL = ""
	if got := viewLink(a, firedNow); got != "" {
		t.Errorf("got %q", got)
	}
}

func TestHumanDurationKeepsTheTwoLargestUnits(t *testing.T) {
	tests := []struct {
		in   time.Duration
		want string
	}{
		{2*time.Hour + 14*time.Minute + 9*time.Second, "2h 14m"},
		{74 * time.Hour, "3d 2h"},
		{45 * time.Second, "45s"},
		{23*time.Minute + 45*time.Second, "23m 45s"},
		{4 * time.Minute, "4m"},
		{2*time.Hour + 30*time.Second, "2h"},
		{48 * time.Hour, "2d"},
		{500 * time.Millisecond, "0s"},
		{0, "0s"},
		{-time.Minute, "0s"},
	}
	for _, tt := range tests {
		if got := humanDuration(tt.in); got != tt.want {
			t.Errorf("humanDuration(%v) = %q, want %q", tt.in, got, tt.want)
		}
	}
}

func TestIssueTitleIsTheSummaryElseWhatAndWhere(t *testing.T) {
	if got := issueTitle(firing(map[string]string{"summary": "Disk on cube is 91% full"})); got != "Disk on cube is 91% full" {
		t.Errorf("got %q", got)
	}
	if got := issueTitle(firing(nil)); got != "HostDiskFilling on cube" {
		t.Errorf("got %q", got)
	}
}

func TestIssueBodyHasEveryPartInOrder(t *testing.T) {
	body := issueBody(firing(map[string]string{
		"condition":   "Root disk above 85%.",
		"description": "It keeps filling.\nLook at the logs first.",
		"check":       "df -h /",
		"dashboard":   "https://grafana.example/d/x",
	}), firedNow, nil)
	want := "Root disk above 85%.\n\n" +
		"It keeps filling.\nLook at the logs first.\n\n" +
		"```\ndf -h /\n```\n\n" +
		"[Dashboard](https://grafana.example/d/x?from=1793689200000&to=now)"
	if body != want {
		t.Errorf("\n got %q\nwant %q", body, want)
	}
}

func TestIssueBodySkipsWhatIsMissing(t *testing.T) {
	a := firing(map[string]string{"check": "  df -h /\n"})
	a.GeneratorURL = ""
	if got, want := issueBody(a, firedNow, nil), "```\ndf -h /\n```"; got != want {
		t.Errorf("got %q, want %q", got, want)
	}
	b := firing(nil)
	b.GeneratorURL = ""
	if got := issueBody(b, firedNow, nil); got != "" {
		t.Errorf("got %q", got)
	}
}

func TestIssueBodyFirstLineSaysHowItRelatesToTheClose(t *testing.T) {
	before := startsAt.Add(-time.Hour)
	after := startsAt.Add(time.Hour)
	tests := []struct {
		name   string
		closed issue
		want   string
	}{
		{"completed before it started", issue{Identifier: "SHA-308", CompletedAt: &before}, "Fired again after SHA-308 was closed."},
		{"canceled before it started", issue{Identifier: "SHA-308", CanceledAt: &before}, "Fired again after SHA-308 was closed."},
		{"completed while it was firing", issue{Identifier: "SHA-318", CompletedAt: &after}, "Still firing after SHA-318 was closed."},
		{"canceled while it was firing", issue{Identifier: "SHA-318", CanceledAt: &after}, "Still firing after SHA-318 was closed."},
		{"closed the moment it started", issue{Identifier: "SHA-318", CompletedAt: &startsAt}, "Still firing after SHA-318 was closed."},
		{"no close time to compare", issue{Identifier: "SHA-308"}, "Fired again after SHA-308 was closed."},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			closed := tt.closed
			body := issueBody(firing(map[string]string{"condition": "Root disk above 85%."}), firedNow, &closed)
			if !strings.HasPrefix(body, tt.want+"\n\nRoot disk above 85%.") {
				t.Errorf("got %q", body)
			}
		})
	}
}

func TestResolvedCommentReadsInMelbourneTime(t *testing.T) {
	got := resolvedComment(finished(map[string]string{"dashboard": "https://grafana.example/d/x"}))
	want := "Stopped firing at 21:14, after 2h 14m. Whatever caused it may still be there; close this when the job is done.\n\n" +
		"[Dashboard](https://grafana.example/d/x?from=1793689200000&to=1793701770000)"
	if got != want {
		t.Errorf("\n got %q\nwant %q", got, want)
	}
}

func TestResolvedCommentWithNothingToLinkToIsJustTheSentence(t *testing.T) {
	a := finished(nil)
	a.GeneratorURL = ""
	want := "Stopped firing at 21:14, after 2h 14m. Whatever caused it may still be there; close this when the job is done."
	if got := resolvedComment(a); got != want {
		t.Errorf("got %q", got)
	}
}
