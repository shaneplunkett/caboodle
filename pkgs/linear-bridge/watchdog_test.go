package main

import (
	"net/http"
	"strings"
	"testing"
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
