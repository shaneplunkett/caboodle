{
  imports = [
    ../modules/services/prometheus
    ../modules/services/smartctl/alerts.nix
    ../modules/services/nas/alerts.nix
    ../modules/services/alertmanager
    ../modules/services/grafana
    ../modules/services/loki
    ../modules/services/blocky/monitoring.nix
    ../modules/services/unbound/monitoring.nix
    ../modules/services/incus/monitoring.nix
    ../modules/services/blackbox
    ../modules/services/unpoller
    ../modules/services/backup/monitoring.nix
    ../modules/services/vex-brain/alerts.nix
  ];
}
