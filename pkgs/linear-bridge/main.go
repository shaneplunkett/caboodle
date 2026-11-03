package main

import (
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"os"
	"strings"
	"time"
)

type config struct {
	listen       []string
	clientID     string
	clientSecret string
	defaults     issueDefaults
	alertsPage   string
	ignored      []string
}

func loadConfig(getenv func(string) string) (config, error) {
	var missing []string
	require := func(key string) string {
		value := getenv(key)
		if value == "" {
			missing = append(missing, key)
		}
		return value
	}
	cfg := config{
		clientID:     require("LINEAR_CLIENT_ID"),
		clientSecret: require("LINEAR_CLIENT_SECRET"),
		defaults: issueDefaults{
			TeamID:     require("LINEAR_TEAM_ID"),
			AssigneeID: require("LINEAR_ASSIGNEE_ID"),
			StateID:    require("LINEAR_STATE_ID"),
			LabelIDs:   strings.Split(require("LINEAR_LABEL_IDS"), ","),
		},
		alertsPage: require("BRIDGE_ALERTS_PAGE"),
	}
	addresses, port := require("BRIDGE_LISTEN_ADDRESSES"), require("BRIDGE_PORT")
	if ignored := getenv("BRIDGE_IGNORED_ALERTS"); ignored != "" {
		cfg.ignored = strings.Split(ignored, ",")
	}
	if len(missing) > 0 {
		return config{}, errors.New("missing environment: " + strings.Join(missing, ", "))
	}
	for _, address := range strings.Split(addresses, ",") {
		address = strings.TrimSpace(address)
		if net.ParseIP(address) == nil {
			return config{}, fmt.Errorf("BRIDGE_LISTEN_ADDRESSES: %q is not an IP address", address)
		}
		cfg.listen = append(cfg.listen, net.JoinHostPort(address, port))
	}
	return cfg, nil
}

func main() {
	log := slog.New(slog.NewTextHandler(os.Stdout, nil))
	if err := run(log); err != nil {
		log.Error("stopping", "error", err)
		os.Exit(1)
	}
}

func newServer(addr string, handler http.Handler) *http.Server {
	return &http.Server{
		Addr:              addr,
		Handler:           handler,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
	}
}

func listenAll(addresses []string) ([]net.Listener, error) {
	listeners := make([]net.Listener, 0, len(addresses))
	for _, address := range addresses {
		listener, err := net.Listen("tcp", address)
		if err != nil {
			for _, open := range listeners {
				open.Close()
			}
			return nil, fmt.Errorf("listening: %w", err)
		}
		listeners = append(listeners, listener)
	}
	return listeners, nil
}

func serveAll(listeners []net.Listener, handler http.Handler) error {
	stopped := make(chan error, len(listeners))
	for _, listener := range listeners {
		go func() {
			stopped <- newServer(listener.Addr().String(), handler).Serve(listener)
		}()
	}
	return fmt.Errorf("serving: %w", <-stopped)
}

func run(log *slog.Logger) error {
	cfg, err := loadConfig(os.Getenv)
	if err != nil {
		return err
	}
	mux := http.NewServeMux()
	mux.Handle("POST /alerts", &bridge{
		linear:     newLinear(linearGraphQLURL, linearTokenURL, cfg.clientID, cfg.clientSecret),
		defaults:   cfg.defaults,
		alertsPage: cfg.alertsPage,
		ignored:    cfg.ignored,
		now:        time.Now,
		log:        log,
	})
	listeners, err := listenAll(cfg.listen)
	if err != nil {
		return err
	}
	log.Info("listening", "addresses", cfg.listen)
	return serveAll(listeners, mux)
}
