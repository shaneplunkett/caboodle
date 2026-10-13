{ lib, nodes }:
let
  prometheus = "http://${nodes.monitoring.config.homelab.lanAddress}:9090/api/v1/query";
  backedUp = lib.attrNames (lib.filterAttrs (_: node: node.config.homelab.backup.paths != [ ]) nodes);

  query = promql: {
    url = prometheus;
    parameters.query = promql;
  };
in
query ''up{job="node", host=~"${lib.concatStringsSep "|" backedUp}"}''
// {
  type = "custom-api";
  title = "Backups";
  cache = "1m";
  subrequests = {
    used = query "homelab_storagebox_used_bytes / 2^30";
    full = query "homelab_storagebox_used_bytes / homelab_storagebox_size_bytes * 100";
    r2used = query "sum(homelab_r2_used_bytes) / 2^30";
    sftp = query ''probe_success{job="storagebox"}'';
    backups = query ''homelab_backup_last_success_timestamp_seconds{task="backup"}'';
    r2 = query ''homelab_backup_last_success_timestamp_seconds{task="r2-backup"}'';
    failing = query ''ALERTS{alertname=~"Backup.*", alertstate="firing"}'';
  };
  template = builtins.readFile ./template.html;
}
