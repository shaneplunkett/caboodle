{ lib }:
let
  inherit (import ./panels.nix { inherit lib; })
    loki
    at
    row
    panel
    bars
    overTime
    dashboard
    ;

  logs = expr: legendFormat: {
    datasource = loki;
    inherit expr legendFormat;
  };

  instantLogs = expr: legendFormat: logs expr legendFormat // { queryType = "instant"; };

  selected = ''host=~"$host", unit=~"$unit"'';
  matching = ''{${selected}} |~ "(?i)$search"'';
  perSession = ''unit!~"sshd@.+|session-.+"'';

  lineCount = {
    unit = "short";
    decimals = 0;
    min = 0;
    color = {
      mode = "fixed";
      fixedColor = "blue";
    };
  };

  labelVariable = name: label: stream: {
    inherit name label;
    type = "query";
    datasource = loki;
    query = {
      type = 1;
      label = name;
      inherit stream;
      refId = name;
    };
    refresh = 2;
    sort = 1;
    multi = true;
    includeAll = true;
    allValue = ".+";
    current = {
      text = "All";
      value = "$__all";
    };
  };
in
dashboard {
  uid = "logs";
  title = "Logs";

  variables = [
    (labelVariable "host" "Host" "")
    (labelVariable "unit" "Unit" ''{host=~"$host"}'')
    {
      name = "search";
      label = "Search";
      type = "textbox";
      query = "";
    }
  ];

  panels = [
    (row "Volume" 0)
    (overTime {
      title = "Lines per minute by level";
      gridPos = at 0 1 16 8;
      datasource = loki;
      stacked = true;
      defaults.unit = "short";
      targets = [
        (logs "sum by (level) (count_over_time(${matching} [1m]))" "{{level}}")
      ];
    })
    (bars {
      title = "Errors by host";
      gridPos = at 16 1 8 8;
      datasource = loki;
      defaults = lineCount // {
        color = {
          mode = "fixed";
          fixedColor = "red";
        };
      };
      targets = [
        (instantLogs ''sort_desc(sum by (host) (count_over_time({${selected}, level="error"} [$__range])))'' "{{host}}")
      ];
    })
    (bars {
      title = "Noisiest units";
      gridPos = at 0 9 24 8;
      datasource = loki;
      defaults = lineCount;
      targets = [
        (instantLogs "sort_desc(topk(10, sum by (host, unit) (count_over_time({${selected}, ${perSession}} [$__range]))))" "{{host}} {{unit}}")
      ];
    })

    (row "Lines" 17)
    (panel {
      type = "logs";
      title = "Logs";
      gridPos = at 0 18 24 20;
      datasource = loki;
      targets = [ (logs matching "") ];
      defaults = { };
      options = {
        showTime = true;
        showLabels = false;
        showCommonLabels = false;
        wrapLogMessage = true;
        prettifyLogMessage = false;
        enableLogDetails = true;
        dedupStrategy = "none";
        sortOrder = "Descending";
      };
    })
  ];
}
