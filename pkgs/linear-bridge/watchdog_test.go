package main

import (
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func watchdog() alert {
	a := firing(map[string]string{"summary": "Always firing"})
	a.Labels = map[string]string{"alertname": "Watchdog"}
	return a
}

func TestWatchdogNeverReachesLinear(t *testing.T) {
	r := newRig(t)
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if r.fake.calls != 0 {
		t.Errorf("made %d calls to Linear", r.fake.calls)
	}
	if len(r.fake.issues) != 0 {
		t.Errorf("filed %d issues", len(r.fake.issues))
	}
}

func TestWatchdogPingsHealthchecks(t *testing.T) {
	r := newRig(t)
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if got := r.pings.Load(); got != 1 {
		t.Errorf("pings = %d", got)
	}
	if line := r.record(t, "verb=ping"); !hasAttr(line, "alertname=Watchdog") {
		t.Errorf("record = %s", line)
	}
}

func TestWatchdogPingIsWithheldAfterLinearRefusesAWrite(t *testing.T) {
	r := newRig(t)
	r.fake.refuseCreate = "RATELIMITED"
	r.post(t, "first notification", diskAlert())
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if got := r.pings.Load(); got != 0 {
		t.Errorf("pings = %d", got)
	}
	line := r.record(t, "verb=withheld")
	if !hasAttr(line, "alertname=Watchdog") || !strings.Contains(line, "RATELIMITED") {
		t.Errorf("record = %s", line)
	}
}

func TestWatchdogPingResumesOnceLinearTakesAWrite(t *testing.T) {
	r := newRig(t)
	r.fake.refuseCreate = "RATELIMITED"
	r.post(t, "first notification", diskAlert())
	r.fake.refuseCreate = ""
	r.post(t, "repeat interval elapsed", diskAlert())
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 1 {
		t.Errorf("pings = %d, want 1", got)
	}
}

func TestWatchdogPingFollowsARefusedAndThenLandedAttachment(t *testing.T) {
	r := newRig(t)
	r.fake.refuseAttach = "FORBIDDEN"
	r.post(t, "first notification", diskAlert())
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 0 {
		t.Fatalf("pings after the refused attachment = %d", got)
	}
	r.fake.refuseAttach = ""
	r.post(t, "repeat interval elapsed", diskAlert())
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 1 {
		t.Errorf("pings after the landed attachment = %d, want 1", got)
	}
}

func TestWatchdogPingFollowsARefusedAndThenLandedComment(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	r.fake.refuseComment = "FORBIDDEN"
	r.post(t, "some alerts resolved", resolvedDiskAlert())
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 0 {
		t.Fatalf("pings after the refused comment = %d", got)
	}
	r.fake.refuseComment = ""
	r.post(t, "some alerts resolved", resolvedDiskAlert())
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 1 {
		t.Errorf("pings after the landed comment = %d, want 1", got)
	}
}

func TestWatchdogPingIsWithheldWhileLinearIsUnreachable(t *testing.T) {
	r := newRig(t)
	r.fake.failFind[diskAlert().identityURL(r.bridge.alertsPage)] = true
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusBadGateway {
		t.Fatalf("status = %d", code)
	}
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 0 {
		t.Errorf("pings = %d", got)
	}
	r.record(t, "verb=withheld")
}

func TestWatchdogPingIsWithheldWhenATokenKeepsBeingRejected(t *testing.T) {
	r := newRig(t)
	r.fake.rejectTokens = true
	r.post(t, "first notification", diskAlert())
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 0 {
		t.Errorf("pings = %d", got)
	}
	if line := r.record(t, "verb=withheld"); !strings.Contains(line, authErrorCode) {
		t.Errorf("record = %s", line)
	}
}

func TestWatchdogPingOutlivesAOneOffFailureWithNothingToWrite(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	url := diskAlert().identityURL(r.bridge.alertsPage)
	r.fake.failFind[url] = true
	r.post(t, "repeat interval elapsed", diskAlert())
	delete(r.fake.failFind, url)
	r.post(t, "repeat interval elapsed", diskAlert())
	r.record(t, "verb=still-firing")
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 1 {
		t.Errorf("pings = %d, want 1", got)
	}
}

func TestWatchdogPingStaysWithheldWhenOnlyAReadLandsAfterARefusedWrite(t *testing.T) {
	r := newRig(t)
	r.fake.refuseCreate = "RATELIMITED"
	r.post(t, "first notification", diskAlert())
	r.post(t, "some alerts resolved", resolvedDiskAlert())
	r.record(t, "verb=resolve-ignored")
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 0 {
		t.Errorf("pings = %d", got)
	}
	if line := r.record(t, "verb=withheld"); !strings.Contains(line, "RATELIMITED") {
		t.Errorf("record = %s", line)
	}
}

func TestWatchdogPingOutlivesAWriteThatNeverReachedLinear(t *testing.T) {
	r := newRig(t)
	r.fake.failCreate = true
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusBadGateway {
		t.Fatalf("status = %d", code)
	}
	r.fake.failCreate = false
	r.post(t, "some alerts resolved", resolvedDiskAlert())
	r.record(t, "verb=resolve-ignored")
	r.post(t, "repeat interval elapsed", watchdog())
	if got := r.pings.Load(); got != 1 {
		t.Errorf("pings = %d, want 1", got)
	}
}

func TestAFreshBridgePingsBeforeItHasEverTalkedToLinear(t *testing.T) {
	r := newRig(t)
	for range 3 {
		r.post(t, "repeat interval elapsed", watchdog())
	}
	if got := r.pings.Load(); got != 3 {
		t.Errorf("pings = %d, want 3", got)
	}
	if r.fake.calls != 0 {
		t.Errorf("made %d calls to Linear", r.fake.calls)
	}
	if got := strings.Count(r.logs.String(), "verb=ping"); got != 3 {
		t.Errorf("verb=ping lines = %d, want 3 in %s", got, r.logs.String())
	}
}

func TestAResolvedWatchdogIsNotAPing(t *testing.T) {
	r := newRig(t)
	a := watchdog()
	a.Status = "resolved"
	a.EndsAt = endsAt
	if code := r.post(t, "some alerts resolved", a); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if got := r.pings.Load(); got != 0 {
		t.Errorf("pings = %d", got)
	}
	if r.fake.calls != 0 {
		t.Errorf("made %d calls to Linear", r.fake.calls)
	}
	r.record(t, "verb=withheld")
}

func TestAPingHealthchecksRefusesAnswersAlertmanager200(t *testing.T) {
	r := newRig(t)
	r.pingStatus.Store(http.StatusInternalServerError)
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if line := r.record(t, "verb=ping"); !hasAttr(line, "level=ERROR") || !strings.Contains(line, "500") {
		t.Errorf("record = %s", line)
	}
}

func TestAPingThatCannotConnectAnswers200AndKeepsTheURLOutOfTheLog(t *testing.T) {
	r := newRig(t)
	r.bridge.heartbeat = newHeartbeat("http://127.0.0.1:1/ping/check-uuid")
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if line := r.record(t, "verb=ping"); !hasAttr(line, "level=ERROR") {
		t.Errorf("record = %s", line)
	}
	if strings.Contains(r.logs.String(), "check-uuid") {
		t.Errorf("the ping URL is in the log: %s", r.logs.String())
	}
}

func logsAfterAPingAgainst(t *testing.T, handler http.HandlerFunc) string {
	t.Helper()
	r := newRig(t)
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)
	r.bridge.heartbeat = newHeartbeat(server.URL + "/ping/check-uuid")
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	r.record(t, "verb=ping")
	return r.logs.String()
}

func TestAMalformedRedirectKeepsThePingPathOutOfTheLog(t *testing.T) {
	logs := logsAfterAPingAgainst(t, func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Location", "/ping/check-uuid/%zz")
		w.WriteHeader(http.StatusFound)
	})
	for _, trace := range []string{"check-uuid", "/ping", "%zz"} {
		if strings.Contains(logs, trace) {
			t.Errorf("%q is in the log: %s", trace, logs)
		}
	}
	if !strings.Contains(logs, "level=ERROR") {
		t.Errorf("logs = %s", logs)
	}
}

func TestAPingNamesWhyItFailedWithoutQuotingTheError(t *testing.T) {
	r := newRig(t)
	r.bridge.heartbeat = newHeartbeat("http://127.0.0.1:1/ping/check-uuid")
	r.post(t, "repeat interval elapsed", watchdog())
	if line := r.record(t, "verb=ping"); !strings.Contains(line, `error="connection refused"`) {
		t.Errorf("record = %s", line)
	}
}

func TestAPingThatTimesOutSaysSo(t *testing.T) {
	r := newRig(t)
	release := make(chan struct{})
	server := httptest.NewServer(http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) { <-release }))
	t.Cleanup(server.Close)
	t.Cleanup(func() { close(release) })
	r.bridge.heartbeat = newHeartbeat(server.URL + "/ping/check-uuid")
	r.bridge.heartbeat.http.Timeout = 50 * time.Millisecond
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if line := r.record(t, "verb=ping"); !strings.Contains(line, `error=timeout`) || strings.Contains(line, "check-uuid") {
		t.Errorf("record = %s", line)
	}
}

type lookupFails struct{}

func (lookupFails) RoundTrip(*http.Request) (*http.Response, error) {
	return nil, &net.DNSError{Err: "no such host", Name: "check-uuid.invalid", IsNotFound: true}
}

func TestAPingAgainstAnUnknownHostSaysSo(t *testing.T) {
	r := newRig(t)
	r.bridge.heartbeat = newHeartbeat("http://check-uuid.invalid/ping/check-uuid")
	r.bridge.heartbeat.http.Transport = lookupFails{}
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	line := r.record(t, "verb=ping")
	if !strings.Contains(line, `error="dns lookup failed"`) || strings.Contains(line, "check-uuid") {
		t.Errorf("record = %s", line)
	}
}

func TestABrokenPingURLStaysOutOfTheLog(t *testing.T) {
	r := newRig(t)
	r.bridge.heartbeat = newHeartbeat("http://bad host/check-uuid")
	if code := r.post(t, "repeat interval elapsed", watchdog()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	line := r.record(t, "verb=ping")
	if !hasAttr(line, "level=ERROR") || strings.Contains(line, "check-uuid") {
		t.Errorf("record = %s", line)
	}
}
