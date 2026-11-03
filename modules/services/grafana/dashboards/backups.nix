{
  lib,
  nodes,
}:
let
  inherit (import ./panels.nix { inherit lib; })
    at
    query
    instant
    percent
    panel
    row
    usageNow
    overTime
    timeline
    upOrDown
    firing
    labelVariable
    dashboard
    ;

  backedUp = lib.attrNames (lib.filterAttrs (_: node: node.config.homelab.backup.paths != [ ]) nodes);

  selected = ''host=~"$host",task=~"$task"'';
  sinceSuccess = "time() - homelab_backup_last_success_timestamp_seconds{${selected}}";
  boxFull = "100 * homelab_storagebox_used_bytes / homelab_storagebox_size_bytes";
  age = {
    unit = "s";
    min = 0;
    decimals = 1;
  };
in
dashboard {
  uid = "backups";
  title = "Backups";

  variables = [
    (labelVariable "host" "Host" ''up{job="node",host=~"${lib.concatStringsSep "|" backedUp}"}'')
    (labelVariable "task" "Task" ''homelab_backup_last_success_timestamp_seconds{host=~"$host"}'')
  ];

  panels = [
    (row "Right now" 0)
    (firing (at 0 1 24 5) "{{alertname}} {{host}} {{task}}" [
      ''alertname=~"StorageBox.*"''
      ''alertname=~"BackupStale|BackupMissing",${selected}''
    ])

    (row "Storage Box" 6)
    (usageNow "Full now" (at 0 7 6 6) "Storage Box" boxFull)
    (overTime {
      title = "Full";
      gridPos = at 6 7 6 6;
      defaults = percent;
      targets = [ (query "Storage Box" boxFull) ];
    })
    (timeline {
      title = "Answering SFTP";
      gridPos = at 12 7 6 6;
      targets = [ (query "Storage Box" ''probe_success{job="storagebox"}'') ];
      states = upOrDown;
    })
    (overTime {
      title = "Age of the usage reading";
      gridPos = at 18 7 6 6;
      defaults = age;
      targets = [
        (query "Storage Box" ''time() - node_textfile_mtime_seconds{file=~".*storagebox.prom"}'')
      ];
    })

    (row "Last success per host and task" 13)
    (
      panel {
        type = "table";
        title = "Time since last success";
        gridPos = at 0 14 24 17;
        defaults = age;
        targets = [ (instant (query "" sinceSuccess) // { format = "table"; }) ];
        options = {
          showHeader = true;
          cellHeight = "sm";
        };
      }
      // {
        transformations = [
          {
            id = "groupingToMatrix";
            options = {
              rowField = "host";
              columnField = "task";
              valueField = "Value";
              emptyValue = "null";
            };
          }
          {
            id = "organize";
            options.renameByName."host\\task" = "Host";
          }
          {
            id = "sortBy";
            options.sort = [ { field = "Host"; } ];
          }
        ];
      }
    )
    (overTime {
      title = "Time since last success, over time";
      gridPos = at 0 31 24 9;
      defaults = age;
      targets = [ (query "{{host}} {{task}}" sinceSuccess) ];
    })
  ];
}
