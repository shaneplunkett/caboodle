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
	listen       string
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
		listen:     net.JoinHostPort("127.0.0.1", require("BRIDGE_PORT")),
		alertsPage: require("BRIDGE_ALERTS_PAGE"),
	}
	if ignored := getenv("BRIDGE_IGNORED_ALERTS"); ignored != "" {
		cfg.ignored = strings.Split(ignored, ",")
	}
	if len(missing) > 0 {
		return config{}, errors.New("missing environment: " + strings.Join(missing, ", "))
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
	server := &http.Server{Addr: cfg.listen, Handler: mux, ReadHeaderTimeout: 10 * time.Second}
	log.Info("listening", "address", cfg.listen)
	return fmt.Errorf("serving: %w", server.ListenAndServe())
}
