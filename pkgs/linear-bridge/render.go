package main

import (
	"fmt"
	"net/url"
	"strconv"
	"strings"
	"time"
	_ "time/tzdata"
)

const (
	windowBefore = time.Hour
	windowAfter  = 15 * time.Minute
)

var melbourne = mustLoadLocation("Australia/Melbourne")

func mustLoadLocation(name string) *time.Location {
	location, err := time.LoadLocation(name)
	if err != nil {
		panic(err)
	}
	return location
}

func issueTitle(a alert) string {
	if summary := strings.TrimSpace(a.Annotations["summary"]); summary != "" {
		return summary
	}
	return a.cardTitle()
}

func issueBody(a alert, now time.Time, lastClosed *issue) string {
	var parts []string
	add := func(part string) {
		if part != "" {
			parts = append(parts, part)
		}
	}
	if lastClosed != nil {
		add(closeLine(a, *lastClosed))
	}
	add(strings.TrimSpace(a.Annotations["condition"]))
	add(strings.TrimSpace(a.Annotations["description"]))
	if check := strings.TrimSpace(a.Annotations["check"]); check != "" {
		add("```\n" + check + "\n```")
	}
	add(viewLink(a, now))
	return strings.Join(parts, "\n\n")
}

func closeLine(a alert, closed issue) string {
	if closedAt := closed.closedAt(); closedAt != nil && !a.StartsAt.After(*closedAt) {
		return "Still firing after " + closed.Identifier + " was closed."
	}
	return "Fired again after " + closed.Identifier + " was closed."
}

func resolvedComment(a alert) string {
	sentence := fmt.Sprintf(
		"Stopped firing at %s, after %s. Whatever caused it may still be there; close this when the job is done.",
		a.EndsAt.In(melbourne).Format("15:04"),
		humanDuration(a.EndsAt.Sub(a.StartsAt)),
	)
	if link := viewLink(a, a.EndsAt); link != "" {
		return sentence + "\n\n" + link
	}
	return sentence
}

func viewLink(a alert, now time.Time) string {
	from := a.StartsAt.Add(-windowBefore)
	to := a.EndsAt.Add(windowAfter)
	if dashboard := strings.TrimSpace(a.Annotations["dashboard"]); dashboard != "" {
		separator := "?"
		if strings.Contains(dashboard, "?") {
			separator = "&"
		}
		toParam := "now"
		if a.resolved() {
			toParam = strconv.FormatInt(to.UnixMilli(), 10)
		}
		return fmt.Sprintf("[Dashboard](%s%sfrom=%d&to=%s)", dashboard, separator, from.UnixMilli(), toParam)
	}
	if a.GeneratorURL == "" {
		return ""
	}
	graph, err := url.Parse(a.GeneratorURL)
	if err != nil {
		return ""
	}
	query := graph.Query()
	query.Set("g0.tab", "graph")
	if a.resolved() {
		query.Set("g0.range_input", to.Sub(from).Round(time.Minute).String())
		query.Set("g0.end_input", to.UTC().Format("2006-01-02T15:04:05Z"))
	} else {
		query.Set("g0.range_input", now.Sub(from).Round(time.Minute).String())
	}
	graph.RawQuery = query.Encode()
	return "[Graph in Prometheus](" + graph.String() + ")"
}

func humanDuration(d time.Duration) string {
	if d < time.Second {
		return "0s"
	}
	units := []struct {
		suffix string
		size   time.Duration
	}{
		{"d", 24 * time.Hour},
		{"h", time.Hour},
		{"m", time.Minute},
		{"s", time.Second},
	}
	for i, unit := range units {
		if d < unit.size {
			continue
		}
		largest := strconv.FormatInt(int64(d/unit.size), 10) + unit.suffix
		if i == len(units)-1 {
			return largest
		}
		next := units[i+1]
		if count := (d % unit.size) / next.size; count > 0 {
			return largest + " " + strconv.FormatInt(int64(count), 10) + next.suffix
		}
		return largest
	}
	return "0s"
}
