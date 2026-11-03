package main

import (
	"io"
	"net"
	"net/http"
	"reflect"
	"strings"
	"testing"
	"time"
)

func fullEnv() map[string]string {
	return map[string]string{
		"LINEAR_CLIENT_ID":        "id",
		"LINEAR_CLIENT_SECRET":    "secret",
		"LINEAR_TEAM_ID":          "team",
		"LINEAR_ASSIGNEE_ID":      "shane",
		"LINEAR_STATE_ID":         "triage",
		"LINEAR_LABEL_IDS":        "bug,needs-triage,repo",
		"BRIDGE_PORT":             "9095",
		"BRIDGE_LISTEN_ADDRESSES": "127.0.0.1",
		"BRIDGE_ALERTS_PAGE":      "https://prometheus.example/alerts",
		"BRIDGE_IGNORED_ALERTS":   "Heartbeat,Other",
	}
}

func TestConfigReadsTheEnvironment(t *testing.T) {
	env := fullEnv()
	got, err := loadConfig(func(key string) string { return env[key] })
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(got.listen, []string{"127.0.0.1:9095"}) {
		t.Errorf("listen = %q", got.listen)
	}
	if !reflect.DeepEqual(got.defaults.LabelIDs, []string{"bug", "needs-triage", "repo"}) {
		t.Errorf("labels = %v", got.defaults.LabelIDs)
	}
	if !reflect.DeepEqual(got.ignored, []string{"Heartbeat", "Other"}) {
		t.Errorf("ignored = %v", got.ignored)
	}
}

func TestConfigListensOnEveryAddressItIsGiven(t *testing.T) {
	tests := []struct {
		name      string
		addresses string
		want      []string
	}{
		{"loopback and the LAN", "127.0.0.1,192.168.1.78", []string{"127.0.0.1:9095", "192.168.1.78:9095"}},
		{"spaces are forgiven", " 127.0.0.1 , 192.168.1.78 ", []string{"127.0.0.1:9095", "192.168.1.78:9095"}},
		{"an IPv6 address gets its brackets", "::1", []string{"[::1]:9095"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			env := fullEnv()
			env["BRIDGE_LISTEN_ADDRESSES"] = tt.addresses
			got, err := loadConfig(func(key string) string { return env[key] })
			if err != nil {
				t.Fatal(err)
			}
			if !reflect.DeepEqual(got.listen, tt.want) {
				t.Errorf("listen = %q, want %q", got.listen, tt.want)
			}
		})
	}
}

func TestConfigRefusesWhatIsNotAnAddress(t *testing.T) {
	for _, addresses := range []string{"monitoring", "127.0.0.1,", "127.0.0.1:9095", "0.0.0.0,lan"} {
		t.Run(addresses, func(t *testing.T) {
			env := fullEnv()
			env["BRIDGE_LISTEN_ADDRESSES"] = addresses
			_, err := loadConfig(func(key string) string { return env[key] })
			if err == nil {
				t.Fatal("wanted an error")
			}
			if !strings.Contains(err.Error(), "BRIDGE_LISTEN_ADDRESSES") {
				t.Errorf("err = %v", err)
			}
		})
	}
}

func TestConfigNamesWhatIsMissing(t *testing.T) {
	env := fullEnv()
	delete(env, "LINEAR_CLIENT_ID")
	delete(env, "BRIDGE_PORT")
	delete(env, "BRIDGE_LISTEN_ADDRESSES")
	_, err := loadConfig(func(key string) string { return env[key] })
	if err == nil {
		t.Fatal("wanted an error")
	}
	for _, name := range []string{"LINEAR_CLIENT_ID", "BRIDGE_PORT", "BRIDGE_LISTEN_ADDRESSES"} {
		if !strings.Contains(err.Error(), name) {
			t.Errorf("err = %v, wanted %s named", err, name)
		}
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

func TestServerBoundsHowLongAPostCanTake(t *testing.T) {
	server := newServer("127.0.0.1:0", http.NewServeMux())
	if server.ReadHeaderTimeout <= 0 {
		t.Errorf("ReadHeaderTimeout = %v", server.ReadHeaderTimeout)
	}
	if server.ReadTimeout <= 0 {
		t.Errorf("ReadTimeout = %v", server.ReadTimeout)
	}
}

func TestEveryAddressAnswers(t *testing.T) {
	listeners, err := listenAll([]string{"127.0.0.1:0", "127.0.0.1:0"})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		for _, listener := range listeners {
			listener.Close()
		}
	})
	go serveAll(listeners, http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		io.WriteString(w, "answered")
	}))
	for _, listener := range listeners {
		response, err := http.Get("http://" + listener.Addr().String())
		if err != nil {
			t.Fatalf("%s: %v", listener.Addr(), err)
		}
		body, _ := io.ReadAll(response.Body)
		response.Body.Close()
		if string(body) != "answered" {
			t.Errorf("%s answered %q", listener.Addr(), body)
		}
	}
}

func TestAnAddressThatWontBindLetsGoOfTheRest(t *testing.T) {
	taken, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	defer taken.Close()
	free, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	freeAddr := free.Addr().String()
	free.Close()

	if _, err := listenAll([]string{freeAddr, taken.Addr().String()}); err == nil {
		t.Fatal("wanted an error")
	}
	again, err := net.Listen("tcp", freeAddr)
	if err != nil {
		t.Fatalf("the first address is still held: %v", err)
	}
	again.Close()
}

func TestServingStopsWhenAnyListenerDies(t *testing.T) {
	listeners, err := listenAll([]string{"127.0.0.1:0", "127.0.0.1:0"})
	if err != nil {
		t.Fatal(err)
	}
	defer listeners[1].Close()
	stopped := make(chan error, 1)
	go func() { stopped <- serveAll(listeners, http.NewServeMux()) }()
	listeners[0].Close()
	select {
	case err := <-stopped:
		if err == nil {
			t.Error("wanted the listener's error")
		}
	case <-time.After(5 * time.Second):
		t.Fatal("still serving after a listener died")
	}
}
