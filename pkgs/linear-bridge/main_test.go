package main

import (
	"reflect"
	"strings"
	"testing"
)

func fullEnv() map[string]string {
	return map[string]string{
		"LINEAR_CLIENT_ID":      "id",
		"LINEAR_CLIENT_SECRET":  "secret",
		"LINEAR_TEAM_ID":        "team",
		"LINEAR_ASSIGNEE_ID":    "shane",
		"LINEAR_STATE_ID":       "triage",
		"LINEAR_LABEL_IDS":      "bug,needs-triage,repo",
		"BRIDGE_PORT":           "9095",
		"BRIDGE_ALERTS_PAGE":    "https://prometheus.example/alerts",
		"BRIDGE_IGNORED_ALERTS": "Heartbeat,Other",
	}
}

func TestConfigListensOnLoopbackOnly(t *testing.T) {
	env := fullEnv()
	got, err := loadConfig(func(key string) string { return env[key] })
	if err != nil {
		t.Fatal(err)
	}
	if got.listen != "127.0.0.1:9095" {
		t.Errorf("listen = %q", got.listen)
	}
	if !reflect.DeepEqual(got.defaults.LabelIDs, []string{"bug", "needs-triage", "repo"}) {
		t.Errorf("labels = %v", got.defaults.LabelIDs)
	}
	if !reflect.DeepEqual(got.ignored, []string{"Heartbeat", "Other"}) {
		t.Errorf("ignored = %v", got.ignored)
	}
}

func TestConfigNamesWhatIsMissing(t *testing.T) {
	env := fullEnv()
	delete(env, "LINEAR_CLIENT_ID")
	delete(env, "BRIDGE_PORT")
	_, err := loadConfig(func(key string) string { return env[key] })
	if err == nil {
		t.Fatal("wanted an error")
	}
	if !strings.Contains(err.Error(), "LINEAR_CLIENT_ID") || !strings.Contains(err.Error(), "BRIDGE_PORT") {
		t.Errorf("err = %v", err)
	}
}

func TestConfigAllowsNothingIgnored(t *testing.T) {
	env := fullEnv()
	delete(env, "BRIDGE_IGNORED_ALERTS")
	got, err := loadConfig(func(key string) string { return env[key] })
	if err != nil {
		t.Fatal(err)
	}
	if len(got.ignored) != 0 {
		t.Errorf("ignored = %v", got.ignored)
	}
}
