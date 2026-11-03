package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/url"
	"time"
)

type payload struct {
	NotificationReason string  `json:"notification_reason"`
	Alerts             []alert `json:"alerts"`
}

type alert struct {
	Status       string            `json:"status"`
	Labels       map[string]string `json:"labels"`
	Annotations  map[string]string `json:"annotations"`
	StartsAt     time.Time         `json:"startsAt"`
	EndsAt       time.Time         `json:"endsAt"`
	GeneratorURL string            `json:"generatorURL"`
	Fingerprint  string            `json:"fingerprint"`
}

func parsePayload(r io.Reader) (payload, error) {
	var p payload
	if err := json.NewDecoder(r).Decode(&p); err != nil {
		return payload{}, fmt.Errorf("decoding payload: %w", err)
	}
	for _, a := range p.Alerts {
		if a.Fingerprint == "" {
			return payload{}, errors.New("alert has no fingerprint")
		}
		if a.name() == "" {
			return payload{}, fmt.Errorf("alert %s has no alertname", a.Fingerprint)
		}
	}
	return p, nil
}

func (a alert) resolved() bool { return a.Status == "resolved" }

func (a alert) name() string { return a.Labels["alertname"] }

func (a alert) where() string {
	for _, label := range []string{"host", "node", "group"} {
		if v := a.Labels[label]; v != "" {
			return v
		}
	}
	return "homelab"
}

func (a alert) cardTitle() string { return a.name() + " on " + a.where() }

func (a alert) identityURL(alertsPage string) string {
	return alertsPage + "?search=" + url.QueryEscape(a.name()) + "&fingerprint=" + url.QueryEscape(a.Fingerprint)
}
