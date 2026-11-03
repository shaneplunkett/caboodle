package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net"
	"net/http"
	"sync"
	"syscall"
	"time"
)

const (
	verbPing     verb = "ping"
	verbWithheld verb = "withheld"
)

var (
	errPingURLInvalid = errors.New("the ping URL is invalid")
	errPingFailed     = errors.New("request failed")
	errPingRefused    = errors.New("connection refused")
	errPingLookup     = errors.New("dns lookup failed")
	errPingTimeout    = errors.New("timeout")
)

type heartbeat struct {
	pingURL string
	http    *http.Client
}

func newHeartbeat(pingURL string) *heartbeat {
	return &heartbeat{pingURL: pingURL, http: &http.Client{Timeout: 10 * time.Second}}
}

func (h *heartbeat) ping(ctx context.Context) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, h.pingURL, nil)
	if err != nil {
		return errPingURLInvalid
	}
	resp, err := h.http.Do(req)
	if err != nil {
		return classifyPingFailure(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode >= http.StatusMultipleChoices {
		return fmt.Errorf("healthchecks.io answered http %d", resp.StatusCode)
	}
	return nil
}

func classifyPingFailure(err error) error {
	var lookup *net.DNSError
	var network net.Error
	switch {
	case errors.As(err, &lookup):
		return errPingLookup
	case errors.As(err, &network) && network.Timeout():
		return errPingTimeout
	case errors.Is(err, syscall.ECONNREFUSED):
		return errPingRefused
	}
	return errPingFailed
}

func (b *bridge) watchdog(ctx context.Context, a alert, log *slog.Logger) {
	reason := b.linear.health.trouble()
	if a.resolved() {
		reason = "the alert resolved"
	}
	if reason != "" {
		log.Warn("watchdog ping withheld", "verb", verbWithheld, "reason", reason)
		return
	}
	if err := b.heartbeat.ping(ctx); err != nil {
		log.Error("healthchecks.io ping failed", "verb", verbPing, "error", err)
		return
	}
	log.Info("watchdog pinged", "verb", verbPing)
}

type linearHealth struct {
	mu      sync.Mutex
	refused string
	failed  string
}

func (h *linearHealth) wrote(err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	var transient *retryableError
	switch {
	case err == nil, errors.Is(err, errAlreadyExists):
		h.refused, h.failed = "", ""
	case errors.As(err, &transient):
		h.failed = err.Error()
	default:
		h.refused = err.Error()
	}
}

func (h *linearHealth) read(err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.failed = ""
	if err != nil {
		h.failed = err.Error()
	}
}

func (h *linearHealth) trouble() string {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.refused != "" {
		return h.refused
	}
	return h.failed
}
