package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func deployFailedPost(t *testing.T) []byte {
	t.Helper()
	posted, err := os.ReadFile("testdata/deploy-failed.json")
	if err != nil {
		t.Fatal(err)
	}
	return posted
}

func TestAFailedDeployFilesAnUrgentIssue(t *testing.T) {
	r := newRig(t)
	post := func() int {
		recorder := httptest.NewRecorder()
		r.bridge.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(deployFailedPost(t))))
		return recorder.Code
	}
	if code := post(); code != http.StatusOK {
		t.Fatalf("status = %d, logs %s", code, r.logs)
	}
	if len(r.fake.issues) != 1 {
		t.Fatalf("filed %d issues", len(r.fake.issues))
	}
	filed := r.fake.issues[0]
	want := map[string]any{
		"title":    "Deploy of cd0a11f failed",
		"priority": float64(priorityUrgent),
		"stateId":  "triage",
		"description": "Commit [cd0a11f](https://github.com/shaneplunkett/caboodle/commit/cd0a11f3aaaabbbbccccddddeeeeffff00001111) failed to deploy, " +
			"in step `apply`, on `monitoring`. [Read the run](https://github.com/shaneplunkett/caboodle/actions/runs/41635043424).\n\n" +
			"Last lines of the apply step:\n\n```\n" +
			"ERROR Failed to deploy to monitoring - Last 20 lines of logs:\n" +
			"ERROR   stderr) warning: the following units failed: linear-bridge.service\n" +
			"ERROR  failure) Activation unit colmena-activate-e5ba on host monitoring failed with result exit-code, exit status 4\n" +
			"ERROR Failed to complete requested operation - Last 1 lines of logs:\n" +
			"```\n\n" +
			"```\ngh run view 41635043424 --repo shaneplunkett/caboodle --log-failed\n```",
	}
	for key, value := range want {
		got, _ := json.Marshal(filed.input[key])
		expected, _ := json.Marshal(value)
		if string(got) != string(expected) {
			t.Errorf("%s = %s, want %s", key, got, expected)
		}
	}
	if len(filed.attachments) != 1 || filed.attachments[0] != "https://prometheus.example/alerts?search=DeployFailed&fingerprint=deploy-41635043424" {
		t.Errorf("attachments = %v", filed.attachments)
	}
	if !strings.Contains(r.logs.String(), "verb=fire") {
		t.Errorf("logs = %s", r.logs)
	}

	if code := post(); code != http.StatusOK || len(r.fake.issues) != 1 {
		t.Errorf("a re-run's post: status %d, %d issues", code, len(r.fake.issues))
	}
	if len(filed.comments) != 0 {
		t.Errorf("comments = %v", filed.comments)
	}
}

func TestARerunAfterEveryAttachFailedFindsTheOrphanAndFilesNoTwin(t *testing.T) {
	const curlAttempts = 6
	r := newRig(t)
	r.fake.failAttach = curlAttempts
	post := func() int {
		recorder := httptest.NewRecorder()
		r.bridge.ServeHTTP(recorder, httptest.NewRequest(http.MethodPost, "/alerts", bytes.NewReader(deployFailedPost(t))))
		return recorder.Code
	}
	for attempt := range curlAttempts {
		if code := post(); code < 500 {
			t.Fatalf("attempt %d: status = %d, curl has to retry this", attempt, code)
		}
	}
	if code := post(); code != http.StatusOK {
		t.Fatalf("the re-run's status = %d, logs %s", code, r.logs)
	}
	if len(r.fake.issues) != 1 {
		t.Fatalf("filed %d issues for one run", len(r.fake.issues))
	}
	if got := r.fake.issues[0].attachments; len(got) != 1 {
		t.Errorf("attachments = %v", got)
	}
	if r.fake.creates != 1 {
		t.Errorf("made %d creates, a rejected one burns an issue number", r.fake.creates)
	}
}

func TestAFailedDeployNeverResolvesAndItsCardNamesTheHost(t *testing.T) {
	p, err := parsePayload(bytes.NewReader(deployFailedPost(t)))
	if err != nil {
		t.Fatal(err)
	}
	a := p.Alerts[0]
	if got := a.cardTitle(); got != "DeployFailed on monitoring" {
		t.Errorf("card = %q", got)
	}
	if a.resolved() || !a.EndsAt.IsZero() {
		t.Errorf("resolved = %v, endsAt = %v", a.resolved(), a.EndsAt)
	}
	if got := viewLink(a, firedNow); got != "" {
		t.Errorf("a second link beside the run's: %q", got)
	}
}
