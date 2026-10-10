{ lib }:
rec {
  prometheus = {
    type = "prometheus";
    uid = "prometheus";
  };

  loki = {
    type = "loki";
    uid = "loki";
  };

  at = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  query = legendFormat: expr: {
    datasource = prometheus;
    inherit expr legendFormat;
  };

  instant =
    target:
    target
    // {
      instant = true;
      range = false;
    };

  percent = {
    unit = "percent";
    min = 0;
    max = 100;
    decimals = 0;
    thresholds = {
      mode = "absolute";
      steps = [
        {
          color = "green";
          value = null;
        }
        {
          color = "orange";
          value = 75;
        }
        {
          color = "red";
          value = 90;
        }
      ];
    };
  };

  byRefId = refId: properties: {
    matcher = {
      id = "byFrameRefID";
      options = refId;
    };
    inherit properties;
  };

  plainNumber = [
    {
      id = "unit";
      value = "none";
    }
    {
      id = "color";
      value = {
        mode = "fixed";
        fixedColor = "text";
      };
    }
  ];

  reduceToLast = {
    calcs = [ "lastNotNull" ];
    fields = "";
    values = false;
  };

  panel =
    {
      type,
      title,
      gridPos,
      targets,
      defaults,
      options,
      overrides ? [ ],
      datasource ? prometheus,
    }:
    {
      inherit
        type
        title
        gridPos
        datasource
        options
        ;
      targets = lib.imap0 (i: target: target // { refId = builtins.substring i 1 "ABCDEFGH"; }) targets;
      fieldConfig = {
        inherit defaults overrides;
      };
    };

  row = title: y: {
    type = "row";
    inherit title;
    gridPos = at 0 y 24 1;
    collapsed = false;
    panels = [ ];
  };

  bars =
    {
      title,
      gridPos,
      targets,
      defaults ? percent,
      datasource ? prometheus,
    }:
    panel {
      type = "bargauge";
      inherit
        title
        gridPos
        defaults
        datasource
        ;
      targets = map instant targets;
      options = {
        orientation = "horizontal";
        displayMode = "basic";
        namePlacement = "left";
        showUnfilled = true;
        reduceOptions = reduceToLast;
      };
    };

  usageNow =
    title: gridPos: legendFormat: expr:
    bars {
      inherit title gridPos;
      targets = [ (query legendFormat "sort_desc(${expr})") ];
    };

  stat =
    {
      title,
      gridPos,
      targets,
      defaults,
      overrides ? [ ],
      sparkline ? false,
    }:
    panel {
      type = "stat";
      inherit
        title
        gridPos
        defaults
        overrides
        ;
      targets = if sparkline then targets else map instant targets;
      options = {
        reduceOptions = reduceToLast;
        textMode = "value_and_name";
        colorMode = "value";
        graphMode = if sparkline then "area" else "none";
        justifyMode = "center";
        orientation = "auto";
      };
    };

  overTime =
    {
      title,
      gridPos,
      targets,
      defaults ? percent,
      stacked ? false,
      datasource ? prometheus,
    }:
    panel {
      type = "timeseries";
      inherit
        title
        gridPos
        targets
        datasource
        ;
      defaults = defaults // {
        custom = {
          lineWidth = 1;
          showPoints = "never";
          fillOpacity = if stacked then 40 else 0;
          stacking = {
            mode = if stacked then "normal" else "none";
            group = "A";
          };
        };
      };
      options = {
        legend = {
          displayMode = "list";
          placement = "bottom";
          showLegend = true;
        };
        tooltip = {
          mode = "multi";
          sort = "desc";
        };
      };
    };

  dashboard =
    {
      uid,
      title,
      panels,
      variables ? [ ],
    }:
    {
      inherit uid title;
      tags = [ "homelab" ];
      timezone = "browser";
      refresh = "1m";
      schemaVersion = 41;
      time = {
        from = "now-24h";
        to = "now";
      };
      templating.list = variables;
      panels = lib.imap1 (id: panel: panel // { inherit id; }) panels;
    };
}
