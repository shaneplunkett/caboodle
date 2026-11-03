package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"slices"
	"time"
)

const (
	priorityUrgent = 1
	priorityMedium = 3
)

type issueDefaults struct {
	TeamID     string
	AssigneeID string
	StateID    string
	LabelIDs   []string
}

type bridge struct {
	linear     *linear
	defaults   issueDefaults
	alertsPage string
	ignored    []string
	now        func() time.Time
	log        *slog.Logger
}

func (b *bridge) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	p, err := parsePayload(r.Body)
	if err != nil {
		b.log.Error("unreadable post from Alertmanager", "error", err)
		http.Error(w, "unreadable payload", http.StatusBadRequest)
		return
	}
	retry := false
	for _, a := range p.Alerts {
		if b.handle(r.Context(), a, p.NotificationReason) {
			retry = true
		}
	}
	if retry {
		http.Error(w, "linear is unreachable", http.StatusBadGateway)
	}
}

func (b *bridge) handle(ctx context.Context, a alert, reason string) (retry bool) {
	log := b.log.With("alertname", a.name(), "fingerprint", a.Fingerprint, "notification_reason", reason)
	if slices.Contains(b.ignored, a.name()) {
		log.Info("alert ignored", "verb", verbIgnored, "status", a.Status)
		return false
	}
	did, identifier, err := b.act(ctx, a)
	log = log.With("verb", did, "issue", identifier)
	var refused *refusal
	switch {
	case err == nil:
		log.Info("alert handled")
	case errors.As(err, &refused):
		log.Error("linear refused, nothing more happens until Alertmanager next sends this alert", "code", refused.Code, "message", refused.Message)
	default:
		log.Warn("linear failed, asking Alertmanager to retry", "error", err)
		return true
	}
	return false
}

func (b *bridge) act(ctx context.Context, a alert) (verb, string, error) {
	attachmentURL := a.identityURL(b.alertsPage)
	issues, err := b.linear.find(ctx, attachmentURL)
	if err != nil {
		return verbLookup, "", err
	}
	d := decide(a.resolved(), issues)
	switch d.verb {
	case verbStillFiring:
		return d.verb, d.open.Identifier, nil
	case verbResolveIgnored:
		return d.verb, identifierOf(d.lastClosed), nil
	case verbResolved:
		id := clientChosenID(d.open.ID, a.Fingerprint, stamp(a.StartsAt), stamp(a.EndsAt))
		err := b.linear.comment(ctx, id, d.open.ID, resolvedComment(a))
		if errors.Is(err, errAlreadyExists) {
			err = nil
		}
		return d.verb, d.open.Identifier, err
	}
	identifier, err := b.file(ctx, a, d.lastClosed, attachmentURL)
	return d.verb, identifier, err
}

func (b *bridge) file(ctx context.Context, a alert, lastClosed *issue, attachmentURL string) (string, error) {
	id := clientChosenID(a.Fingerprint, stamp(a.StartsAt), identifierOf(lastClosed))
	identifier := ""
	created, err := b.linear.createIssue(ctx, newIssue{
		ID:          id,
		TeamID:      b.defaults.TeamID,
		Title:       issueTitle(a),
		Description: issueBody(a, b.now(), lastClosed),
		StateID:     b.defaults.StateID,
		AssigneeID:  b.defaults.AssigneeID,
		LabelIDs:    b.defaults.LabelIDs,
		Priority:    priority(a),
	})
	switch {
	case err == nil:
		identifier = created.Identifier
	case !errors.Is(err, errAlreadyExists):
		return "", err
	}
	attached, err := b.linear.attach(ctx, id, attachmentURL, a.cardTitle())
	if err != nil {
		return identifier, err
	}
	return attached.Identifier, nil
}

func priority(a alert) int {
	if a.Labels["severity"] == "critical" {
		return priorityUrgent
	}
	return priorityMedium
}

func stamp(t time.Time) string { return t.UTC().Format(time.RFC3339Nano) }
