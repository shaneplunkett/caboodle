{
  username = "Homelab";
  color = ''{{ if eq .Status "resolved" }}#a6e3a1{{ else if eq .CommonLabels.severity "critical" }}#f38ba8{{ else }}#fab387{{ end }}'';
  title = ''{{ if eq .Status "firing" }}🔥 {{ .CommonLabels.alertname }}{{ else }}✅ Resolved: {{ .CommonLabels.alertname }}{{ end }}'';
  title_link = ''{{ template "view" (index .Alerts 0) }}'';
  text = ''
    {{ range .Alerts }}{{ if eq .Status "resolved" }}🟢{{ else if eq .Labels.severity "critical" }}🔴{{ else }}🟠{{ end }} **{{ .Annotations.summary }}** · [view]({{ template "view" . }})
    {{ with .Annotations.condition }}{{ . }} · {{ end }}{{ if eq .Status "resolved" }}lasted {{ .EndsAt.Sub .StartsAt | humanizeDuration }}{{ else }}firing for {{ .StartsAt | since | humanizeDuration }}{{ end }}
    {{ if eq .Status "firing" }}{{ with .Annotations.check }}`{{ . }}`
    {{ end }}{{ end }}{{ end }}'';
  fields = [
    {
      title = "Severity";
      value = "{{ .CommonLabels.severity }}";
      short = true;
    }
    {
      title = "Where";
      value = ''{{ or .CommonLabels.node .CommonLabels.host .CommonLabels.group "homelab" }}'';
      short = true;
    }
    {
      title = ''{{ if eq .Status "resolved" }}Resolved{{ else }}Since{{ end }}'';
      value = ''{{ if eq .Status "resolved" }}{{ (index .Alerts 0).EndsAt | tz "Australia/Melbourne" | date "15:04" }}{{ else }}{{ (index .Alerts 0).StartsAt | tz "Australia/Melbourne" | date "15:04" }}{{ end }}'';
      short = true;
    }
    {
      title = "Alerts";
      value = "{{ len .Alerts.Firing }} firing · {{ len .Alerts.Resolved }} resolved";
      short = true;
    }
  ];
  footer = "Homelab · Alertmanager";
}
