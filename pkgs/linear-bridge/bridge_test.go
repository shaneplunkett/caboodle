package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"slices"
	"strings"
	"sync"
	"testing"
	"time"
)

type fakeIssue struct {
	id, identifier, stateType string
	number                    int
	completedAt               *time.Time
	input                     map[string]any
	comments                  []string
	attachments               []string
}

type fakeLinear struct {
	mu           sync.Mutex
	issues       []*fakeIssue
	commentIDs   map[string]bool
	nextNumber   int
	calls        int
	failAttach   int
	refuseCreate string
	failFind     map[string]bool
	garbleFind   bool
	failByID     bool
	creates      int
}

func (i *fakeIssue) node() map[string]any {
	return map[string]any{
		"id": i.id, "identifier": i.identifier, "number": i.number,
		"completedAt": i.completedAt, "canceledAt": nil,
		"state": map[string]any{"type": i.stateType},
	}
}

func (f *fakeLinear) find(url string) []map[string]any {
	nodes := []map[string]any{}
	for _, i := range f.issues {
		for _, attached := range i.attachments {
			if attached == url {
				nodes = append(nodes, map[string]any{"issue": i.node()})
			}
		}
	}
	return nodes
}

func (f *fakeLinear) byID(id string) *fakeIssue {
	for _, i := range f.issues {
		if i.id == id {
			return i
		}
	}
	return nil
}

func graphQLRefusal(w http.ResponseWriter, code, message string) {
	json.NewEncoder(w).Encode(map[string]any{"errors": []map[string]any{{
		"message": message, "extensions": map[string]any{"code": code},
	}}})
}

func (f *fakeLinear) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if r.URL.Path == "/oauth/token" {
		fmt.Fprint(w, `{"access_token":"token"}`)
		return
	}
	f.calls++
	var body struct {
		Query     string
		Variables map[string]any
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		panic(err)
	}
	input, _ := body.Variables["input"].(map[string]any)
	data := map[string]any{}
	switch {
	case strings.Contains(body.Query, "attachmentsForURL"):
		url := body.Variables["url"].(string)
		if f.failFind[url] {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		if f.garbleFind {
			fmt.Fprint(w, `<html>not graphql</html>`)
			return
		}
		data["attachmentsForURL"] = map[string]any{"nodes": f.find(url)}
	case strings.Contains(body.Query, "issues("):
		if f.failByID {
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		nodes := []map[string]any{}
		if found := f.byID(body.Variables["id"].(string)); found != nil {
			nodes = append(nodes, found.node())
		}
		data["issues"] = map[string]any{"nodes": nodes}
	case strings.Contains(body.Query, "issueCreate"):
		f.creates++
		if f.refuseCreate != "" {
			graphQLRefusal(w, f.refuseCreate, "refused")
			return
		}
		id := input["id"].(string)
		if f.byID(id) != nil {
			graphQLRefusal(w, "INPUT_ERROR", "Entity Issue with id "+id+" already exists.")
			return
		}
		f.nextNumber++
		created := &fakeIssue{id: id, identifier: fmt.Sprintf("SHA-%d", f.nextNumber), number: f.nextNumber, stateType: "triage", input: input}
		f.issues = append(f.issues, created)
		data["issueCreate"] = map[string]any{"success": true, "issue": map[string]any{"id": id, "identifier": created.identifier}}
	case strings.Contains(body.Query, "attachmentCreate"):
		if f.failAttach > 0 {
			f.failAttach--
			w.WriteHeader(http.StatusBadGateway)
			return
		}
		target := f.byID(input["issueId"].(string))
		target.attachments = append(target.attachments, input["url"].(string))
		data["attachmentCreate"] = map[string]any{"success": true, "attachment": map[string]any{
			"issue": map[string]any{"id": target.id, "identifier": target.identifier},
		}}
	case strings.Contains(body.Query, "commentCreate"):
		id := input["id"].(string)
		if f.commentIDs[id] {
			graphQLRefusal(w, "INPUT_ERROR", "Entity Comment with id "+id+" already exists.")
			return
		}
		if f.commentIDs == nil {
			f.commentIDs = map[string]bool{}
		}
		f.commentIDs[id] = true
		target := f.byID(input["issueId"].(string))
		target.comments = append(target.comments, input["body"].(string))
		data["commentCreate"] = map[string]any{"success": true}
	default:
		panic("the bridge sent something it should never send: " + body.Query)
	}
	json.NewEncoder(w).Encode(map[string]any{"data": data})
}

func (f *fakeLinear) close(identifier string, at time.Time) {
	for _, i := range f.issues {
		if i.identifier == identifier {
			i.stateType = "completed"
			i.completedAt = &at
		}
	}
}

type rig struct {
	fake   *fakeLinear
	bridge *bridge
	logs   *bytes.Buffer
}

func newRig(t *testing.T) *rig {
	t.Helper()
	fake := &fakeLinear{failFind: map[string]bool{}}
	server := httptest.NewServer(fake)
	t.Cleanup(server.Close)
	logs := &bytes.Buffer{}
	return &rig{
		fake: fake,
		logs: logs,
		bridge: &bridge{
			linear: newLinear(server.URL+"/graphql", server.URL+"/oauth/token", "id", "secret"),
			defaults: issueDefaults{
				TeamID:     "team",
				AssigneeID: "shane",
				StateID:    "triage",
				LabelIDs:   []string{"bug", "needs-triage", "repo"},
			},
			alertsPage: "https://prometheus.example/alerts",
			ignored:    []string{"Heartbeat"},
			now:        func() time.Time { return firedNow },
			log:        slog.New(slog.NewTextHandler(logs, nil)),
		},
	}
}

func (r *rig) post(t *testing.T, reason string, alerts ...alert) int {
	t.Helper()
	body, err := json.Marshal(payload{NotificationReason: reason, Alerts: alerts})
	if err != nil {
		t.Fatal(err)
	}
	recorder := httptest.NewRecorder()
	r.bridge.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(body)))
	return recorder.Code
}

func (r *rig) record(t *testing.T, attr string) string {
	t.Helper()
	for _, line := range strings.Split(r.logs.String(), "\n") {
		if hasAttr(line, attr) {
			return line
		}
	}
	t.Fatalf("no record with %s in %s", attr, r.logs.String())
	return ""
}

func hasAttr(line, attr string) bool {
	return slices.Contains(strings.Fields(line), attr)
}

func diskAlert() alert {
	a := firing(map[string]string{
		"summary":   "Disk on cube is 91% full",
		"condition": "Root disk above 85%.",
		"check":     "df -h /",
		"dashboard": "https://grafana.example/d/x",
	})
	a.Labels["severity"] = "warning"
	return a
}

func resolvedDiskAlert() alert {
	a := diskAlert()
	a.Status = "resolved"
	a.EndsAt = endsAt
	return a
}

func TestFiringFilesTheAgreedIssue(t *testing.T) {
	r := newRig(t)
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 1 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	filed := r.fake.issues[0]
	want := map[string]any{
		"teamId":      "team",
		"assigneeId":  "shane",
		"stateId":     "triage",
		"title":       "Disk on cube is 91% full",
		"priority":    float64(3),
		"labelIds":    []any{"bug", "needs-triage", "repo"},
		"description": "Root disk above 85%.\n\n```\ndf -h /\n```\n\n[Dashboard](https://grafana.example/d/x?from=1793689200000&to=now)",
	}
	for key, value := range want {
		got, _ := json.Marshal(filed.input[key])
		expected, _ := json.Marshal(value)
		if string(got) != string(expected) {
			t.Errorf("%s = %s, want %s", key, got, expected)
		}
	}
	if len(filed.attachments) != 1 || filed.attachments[0] != "https://prometheus.example/alerts?search=HostDiskFilling&fingerprint=003b0a0f7d3fa569" {
		t.Errorf("attachments = %v", filed.attachments)
	}
	for _, part := range []string{"level=INFO", "verb=fire", "alertname=HostDiskFilling", "fingerprint=003b0a0f7d3fa569", "issue=SHA-1", `notification_reason="first notification"`} {
		if !strings.Contains(r.logs.String(), part) {
			t.Errorf("log %q has no %q", r.logs.String(), part)
		}
	}
}

func TestCriticalIsUrgent(t *testing.T) {
	r := newRig(t)
	a := diskAlert()
	a.Labels["severity"] = "critical"
	r.post(t, "first notification", a)
	if got := r.fake.issues[0].input["priority"]; got != float64(1) {
		t.Errorf("priority = %v", got)
	}
}

func TestStillFiringFilesNothingNew(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	if code := r.post(t, "repeat interval elapsed", diskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 1 {
		t.Errorf("filed %d issues", len(r.fake.issues))
	}
	if line := r.record(t, "verb=still-firing"); !hasAttr(line, "issue=SHA-1") {
		t.Errorf("record = %s", line)
	}
}

func TestResolvedCommentsAndLeavesTheIssueOpen(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	filed := r.fake.issues[0]
	want := "Stopped firing at 21:14, after 2h 14m. Whatever caused it may still be there; close this when the job is done.\n\n" +
		"[Dashboard](https://grafana.example/d/x?from=1793689200000&to=1793701770000)"
	if len(filed.comments) != 1 || filed.comments[0] != want {
		t.Errorf("comments = %q", filed.comments)
	}
	if filed.stateType != "triage" {
		t.Errorf("state = %s", filed.stateType)
	}
}

func TestARetriedResolveCommentsOnce(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	r.post(t, "all alerts resolved", resolvedDiskAlert())
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if got := r.fake.issues[0].comments; len(got) != 1 {
		t.Errorf("comments = %q", got)
	}
}

func TestResolveWithNoOpenIssueIsLoggedAndSilent(t *testing.T) {
	r := newRig(t)
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 0 {
		t.Error("a resolve must not file anything")
	}
	r.post(t, "first notification", diskAlert())
	r.fake.close("SHA-1", firedNow)
	r.post(t, "all alerts resolved", resolvedDiskAlert())
	if got := r.fake.issues[0].comments; len(got) != 0 {
		t.Errorf("comments = %q", got)
	}
	if strings.Count(r.logs.String(), "verb=resolve-ignored") != 2 {
		t.Errorf("logs = %s", r.logs.String())
	}
}

func TestAFreshStartAfterACloseFilesAgainNamingTheOldOne(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	r.fake.close("SHA-1", firedNow)
	again := diskAlert()
	again.StartsAt = firedNow.Add(time.Hour)
	r.post(t, "first notification", again)
	if len(r.fake.issues) != 2 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	body := r.fake.issues[1].input["description"].(string)
	if !strings.HasPrefix(body, "Fired again after SHA-1 was closed.\n\nRoot disk") {
		t.Errorf("body = %q", body)
	}
	if !strings.Contains(r.logs.String(), "verb=refire") {
		t.Errorf("logs = %s", r.logs.String())
	}
}

func TestClosedWhileFiringFilesAgainSayingItNeverStopped(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	r.fake.close("SHA-1", firedNow)
	r.post(t, "repeat interval elapsed", diskAlert())
	if len(r.fake.issues) != 2 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	body := r.fake.issues[1].input["description"].(string)
	if !strings.HasPrefix(body, "Still firing after SHA-1 was closed.") {
		t.Errorf("body = %q", body)
	}
}

func TestAFailedAttachAsksForARetryThatFilesNoTwin(t *testing.T) {
	r := newRig(t)
	r.fake.failAttach = 1
	if code := r.post(t, "first notification", diskAlert()); code < 500 {
		t.Fatalf("status = %d, Alertmanager has to retry this", code)
	}
	if line := r.record(t, "verb=fire"); !hasAttr(line, "level=WARN") || !hasAttr(line, "issue=SHA-1") {
		t.Errorf("record = %s", line)
	}
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusOK {
		t.Fatalf("retry status = %d", code)
	}
	if len(r.fake.issues) != 1 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	if got := r.fake.issues[0].attachments; len(got) != 1 {
		t.Errorf("attachments = %v", got)
	}
	if r.fake.creates != 1 {
		t.Errorf("made %d creates, a rejected one burns an issue number", r.fake.creates)
	}
	if line := r.record(t, "verb=still-firing"); !hasAttr(line, "level=INFO") || !hasAttr(line, "issue=SHA-1") {
		t.Errorf("record = %s", line)
	}
}

func TestAResolveBeforeRecoveryStillCommentsOnTheOrphan(t *testing.T) {
	r := newRig(t)
	r.fake.failAttach = 1
	if code := r.post(t, "first notification", diskAlert()); code < 500 {
		t.Fatalf("status = %d", code)
	}
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 1 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	filed := r.fake.issues[0]
	if len(filed.attachments) != 1 || filed.attachments[0] != "https://prometheus.example/alerts?search=HostDiskFilling&fingerprint=003b0a0f7d3fa569" {
		t.Errorf("attachments = %v", filed.attachments)
	}
	if len(filed.comments) != 1 || !strings.HasPrefix(filed.comments[0], "Stopped firing at 21:14") {
		t.Errorf("comments = %q", filed.comments)
	}
	if filed.stateType != "triage" {
		t.Errorf("state = %s", filed.stateType)
	}
	if line := r.record(t, "verb=resolved"); !hasAttr(line, "issue=SHA-1") {
		t.Errorf("record = %s", line)
	}
}

func TestARefiredOrphanRecoversToo(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	r.fake.close("SHA-1", firedNow)
	again := diskAlert()
	again.StartsAt = firedNow.Add(time.Hour)
	r.fake.failAttach = 1
	if code := r.post(t, "first notification", again); code < 500 {
		t.Fatalf("status = %d", code)
	}
	over := again
	over.Status = "resolved"
	over.EndsAt = again.StartsAt.Add(time.Hour)
	if code := r.post(t, "all alerts resolved", over); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 2 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	if got := r.fake.issues[1].comments; len(got) != 1 {
		t.Errorf("comments = %q", got)
	}
	if got := r.fake.issues[0].comments; len(got) != 0 {
		t.Errorf("the closed issue got comments %q", got)
	}
}

func TestAFailedRecoveryAttachAsksForARetry(t *testing.T) {
	r := newRig(t)
	r.fake.failAttach = 2
	r.post(t, "first notification", diskAlert())
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code < 500 {
		t.Fatalf("status = %d", code)
	}
	if got := r.fake.issues[0].comments; len(got) != 0 {
		t.Errorf("commented %q before the attach landed", got)
	}
	if line := r.record(t, "verb=resolved"); !hasAttr(line, "level=WARN") || !hasAttr(line, "issue=SHA-1") {
		t.Errorf("record = %s", line)
	}
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if got := r.fake.issues[0].comments; len(got) != 1 {
		t.Errorf("comments = %q", got)
	}
}

func TestAnOrphanClosedByHandGetsNoComment(t *testing.T) {
	r := newRig(t)
	r.fake.failAttach = 1
	r.post(t, "first notification", diskAlert())
	r.fake.close("SHA-1", firedNow)
	if code := r.post(t, "all alerts resolved", resolvedDiskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if got := r.fake.issues[0].comments; len(got) != 0 {
		t.Errorf("comments = %q", got)
	}
	r.record(t, "verb=resolve-ignored")
}

func TestAnOrphanClosedByHandThatStillFiresFilesAgainNamingIt(t *testing.T) {
	r := newRig(t)
	r.fake.failAttach = 1
	r.post(t, "first notification", diskAlert())
	r.fake.close("SHA-1", firedNow)
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 1 {
		t.Fatalf("filed %d issues, the close should attach first", len(r.fake.issues))
	}
	if got := r.fake.issues[0].attachments; len(got) != 1 {
		t.Errorf("attachments = %v", got)
	}
	if code := r.post(t, "repeat interval elapsed", diskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 2 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	body := r.fake.issues[1].input["description"].(string)
	if !strings.HasPrefix(body, "Still firing after SHA-1 was closed.") {
		t.Errorf("body = %q", body)
	}
}

func TestAFailedOrphanLookupAsksForARetry(t *testing.T) {
	r := newRig(t)
	r.fake.failByID = true
	if code := r.post(t, "first notification", diskAlert()); code < 500 {
		t.Fatalf("status = %d", code)
	}
	if r.fake.creates != 0 {
		t.Errorf("made %d creates without knowing about an orphan", r.fake.creates)
	}
	if line := r.record(t, "verb=lookup"); !hasAttr(line, "level=WARN") {
		t.Errorf("record = %s", line)
	}
}

func TestARefusalIsNotRetriedAndSaysWhatWasLost(t *testing.T) {
	r := newRig(t)
	r.fake.refuseCreate = "USAGE_LIMIT_EXCEEDED"
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d, a retry can't fix a refusal", code)
	}
	for _, part := range []string{"level=ERROR", "verb=fire", "alertname=HostDiskFilling", "code=USAGE_LIMIT_EXCEEDED"} {
		if !strings.Contains(r.logs.String(), part) {
			t.Errorf("log %q has no %q", r.logs.String(), part)
		}
	}
}

func TestAnAnswerItCantReadIsLostNotRetried(t *testing.T) {
	r := newRig(t)
	r.fake.garbleFind = true
	if code := r.post(t, "first notification", diskAlert()); code != http.StatusOK {
		t.Fatalf("status = %d, a retry can't fix this", code)
	}
	if len(r.fake.issues) != 0 {
		t.Errorf("filed %d issues without knowing what was already open", len(r.fake.issues))
	}
	line := r.record(t, "verb=lookup")
	for _, attr := range []string{"level=ERROR", "alertname=HostDiskFilling", "fingerprint=003b0a0f7d3fa569"} {
		if !hasAttr(line, attr) {
			t.Errorf("record %q has no %s", line, attr)
		}
	}
}

func TestOneBadAlertDoesntStopItsSiblings(t *testing.T) {
	r := newRig(t)
	bad := diskAlert()
	bad.Fingerprint = "bad"
	r.fake.failFind["https://prometheus.example/alerts?search=HostDiskFilling&fingerprint=bad"] = true
	good := diskAlert()
	if code := r.post(t, "new alerts added", bad, good); code < 500 {
		t.Fatalf("status = %d", code)
	}
	if len(r.fake.issues) != 1 {
		t.Errorf("filed %d issues", len(r.fake.issues))
	}
	if strings.Count(r.logs.String(), "\n") != 2 {
		t.Errorf("want one line per alert, got %s", r.logs.String())
	}
}

func TestAMixedPostGoesAlertByAlert(t *testing.T) {
	r := newRig(t)
	r.post(t, "first notification", diskAlert())
	over := resolvedDiskAlert()
	other := diskAlert()
	other.Fingerprint = "other"
	other.Labels = map[string]string{"alertname": "HostDiskFilling", "host": "pve"}
	r.post(t, "some alerts resolved", over, other)
	if len(r.fake.issues) != 2 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	if got := r.fake.issues[0].comments; len(got) != 1 {
		t.Errorf("comments = %q", got)
	}
}

func TestIgnoredAlertsNeverTouchLinear(t *testing.T) {
	r := newRig(t)
	a := diskAlert()
	a.Labels["alertname"] = "Heartbeat"
	if code := r.post(t, "first notification", a); code != http.StatusOK {
		t.Fatalf("status = %d", code)
	}
	if r.fake.calls != 0 {
		t.Errorf("made %d calls", r.fake.calls)
	}
	if !strings.Contains(r.logs.String(), "verb=ignored") || !strings.Contains(r.logs.String(), "alertname=Heartbeat") {
		t.Errorf("logs = %s", r.logs.String())
	}
}

func postOfSize(size int) *bytes.Buffer {
	return bytes.NewBufferString(`{"padding":"` + strings.Repeat("x", size) + `","alerts":[]}`)
}

func TestAnOversizedPostIsRefusedAndLogged(t *testing.T) {
	r := newRig(t)
	recorder := httptest.NewRecorder()
	r.bridge.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/alerts", postOfSize(1<<20)))
	if recorder.Code != http.StatusRequestEntityTooLarge {
		t.Errorf("status = %d", recorder.Code)
	}
	if !strings.Contains(r.logs.String(), "level=ERROR") {
		t.Errorf("logs = %s", r.logs.String())
	}
}

func TestAPostUnderTheLimitIsRead(t *testing.T) {
	r := newRig(t)
	recorder := httptest.NewRecorder()
	r.bridge.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/alerts", postOfSize(1<<20-100)))
	if recorder.Code != http.StatusOK {
		t.Errorf("status = %d", recorder.Code)
	}
}

func TestAnUnreadablePostIsABadRequest(t *testing.T) {
	r := newRig(t)
	recorder := httptest.NewRecorder()
	r.bridge.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/alerts", strings.NewReader(`{"alerts":[`)))
	if recorder.Code != http.StatusBadRequest {
		t.Errorf("status = %d", recorder.Code)
	}
	if !strings.Contains(r.logs.String(), "level=ERROR") {
		t.Errorf("logs = %s", r.logs.String())
	}
}
