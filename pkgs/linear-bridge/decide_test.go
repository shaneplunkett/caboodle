package main

import "testing"

func TestDecide(t *testing.T) {
	triage := issue{ID: "open", Identifier: "SHA-20", Number: 20, StateType: "triage"}
	started := issue{ID: "started", Identifier: "SHA-30", Number: 30, StateType: "started"}
	done := issue{ID: "done", Identifier: "SHA-10", Number: 10, StateType: "completed"}
	canceled := issue{ID: "canceled", Identifier: "SHA-40", Number: 40, StateType: "canceled"}
	duplicate := issue{ID: "duplicate", Identifier: "SHA-50", Number: 50, StateType: "duplicate"}

	tests := []struct {
		name       string
		resolved   bool
		issues     []issue
		wantVerb   verb
		wantOpen   string
		wantClosed string
	}{
		{"first fire", false, nil, verbFire, "", ""},
		{"still firing leaves the open one", false, []issue{done, triage}, verbStillFiring, "SHA-20", "SHA-10"},
		{"fires again after a close", false, []issue{done}, verbRefire, "", "SHA-10"},
		{"names the highest closed", false, []issue{canceled, done, duplicate}, verbRefire, "", "SHA-50"},
		{"duplicate counts as closed", false, []issue{duplicate}, verbRefire, "", "SHA-50"},
		{"resolve comments on the open one", true, []issue{done, triage}, verbResolved, "SHA-20", "SHA-10"},
		{"resolve picks the newest open twin", true, []issue{triage, started}, verbResolved, "SHA-30", ""},
		{"resolve after a close is silent", true, []issue{done, canceled}, verbResolveIgnored, "", "SHA-40"},
		{"resolve with nothing filed is silent", true, nil, verbResolveIgnored, "", ""},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := decide(tt.resolved, tt.issues)
			if got.verb != tt.wantVerb {
				t.Errorf("verb = %q, want %q", got.verb, tt.wantVerb)
			}
			if id := identifierOf(got.open); id != tt.wantOpen {
				t.Errorf("open = %q, want %q", id, tt.wantOpen)
			}
			if id := identifierOf(got.lastClosed); id != tt.wantClosed {
				t.Errorf("lastClosed = %q, want %q", id, tt.wantClosed)
			}
		})
	}
}

func TestClientChosenIDIsAStableV4UUID(t *testing.T) {
	// sha256 of "003b0a0f7d3fa569\n2026-11-03T08:00:00Z\nSHA-308", first 16 bytes, version and variant set.
	want := "695cc184-8dd4-4c51-bb9e-4df0761d12f1"
	got := clientChosenID("003b0a0f7d3fa569", "2026-11-03T08:00:00Z", "SHA-308")
	if got != want {
		t.Errorf("got %s, want %s", got, want)
	}
	if other := clientChosenID("003b0a0f7d3fa569", "2026-11-03T08:00:00Z", "SHA-309"); other == got {
		t.Error("a new closed identifier has to change the id, or a close-while-firing can never file again")
	}
	if other := clientChosenID("003b0a0f7d3fa569", "2026-11-03T08:00:01Z", "SHA-308"); other == got {
		t.Error("a new startsAt has to change the id")
	}
}
