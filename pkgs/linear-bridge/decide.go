package main

import (
	"crypto/sha256"
	"fmt"
	"strings"
	"time"
)

type verb string

const (
	verbFire           verb = "fire"
	verbRefire         verb = "refire"
	verbStillFiring    verb = "still-firing"
	verbResolved       verb = "resolved"
	verbResolveIgnored verb = "resolve-ignored"
	verbIgnored        verb = "ignored"
	verbLookup         verb = "lookup"
)

type issue struct {
	ID          string     `json:"id"`
	Identifier  string     `json:"identifier"`
	Number      float64    `json:"number"`
	CompletedAt *time.Time `json:"completedAt"`
	CanceledAt  *time.Time `json:"canceledAt"`
	StateType   string     `json:"-"`
}

func (i issue) closed() bool {
	switch i.StateType {
	case "completed", "canceled", "duplicate":
		return true
	}
	return false
}

func (i issue) closedAt() *time.Time {
	if i.CompletedAt != nil {
		return i.CompletedAt
	}
	return i.CanceledAt
}

type decision struct {
	verb       verb
	open       *issue
	lastClosed *issue
}

func decide(resolved bool, issues []issue) decision {
	var d decision
	for _, candidate := range issues {
		if candidate.closed() {
			d.lastClosed = newest(d.lastClosed, candidate)
		} else {
			d.open = newest(d.open, candidate)
		}
	}
	switch {
	case resolved && d.open != nil:
		d.verb = verbResolved
	case resolved:
		d.verb = verbResolveIgnored
	case d.open != nil:
		d.verb = verbStillFiring
	case d.lastClosed != nil:
		d.verb = verbRefire
	default:
		d.verb = verbFire
	}
	return d
}

func newest(current *issue, candidate issue) *issue {
	if current == nil || candidate.Number > current.Number {
		return &candidate
	}
	return current
}

func identifierOf(i *issue) string {
	if i == nil {
		return ""
	}
	return i.Identifier
}

func clientChosenID(parts ...string) string {
	sum := sha256.Sum256([]byte(strings.Join(parts, "\n")))
	id := sum[:16]
	id[6] = id[6]&0x0f | 0x40
	id[8] = id[8]&0x3f | 0x80
	return fmt.Sprintf("%x-%x-%x-%x-%x", id[:4], id[4:6], id[6:8], id[8:10], id[10:])
}
