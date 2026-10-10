{ lib, nodes }:
let
  inherit (import ./panels.nix { inherit lib; })
    loki
    at
    query
    byRefId
    row
    panel
    bars
    stat
    overTime
    dashboard
    ;

  realClients = import ../../blocky/real-clients.nix { inherit nodes; };

  topClients =
    counter:
    ''sort_desc(topk(10, sum by (client) (label_replace(increase(${counter}[$__range]), "client", "$1", "client", "([a-zA-Z][^.]*)\\..*"))))'';

  responses = selector: "blocky_client_response_total{${realClients}${selector}}";
  shareOf =
    responseType:
    "100 * sum(increase(${responses '',response_type="${responseType}"''}[$__range])) / sum(increase(${responses ""}[$__range]))";
  upstreamP95 =
    by: window:
    ''histogram_quantile(0.95, sum by (${by}) (rate(blocky_request_duration_seconds_bucket{response_type="RESOLVED"}[${window}])))'';

  count = {
    unit = "short";
    decimals = 0;
    min = 0;
    color = {
      mode = "fixed";
      fixedColor = "text";
    };
  };

  topBars =
    title: gridPos: target:
    bars {
      inherit title gridPos;
      targets = [ target ];
      defaults = count // {
        color = {
          mode = "fixed";
          fixedColor = "blue";
        };
      };
    };
in
dashboard {
  uid = "dns";
  title = "DNS";

  panels = [
    (row "Last $__range" 0)
    (stat {
      title = "Summary";
      gridPos = at 0 1 24 4;
      targets = [
        (query "Queries" "sum(increase(${responses ""}[$__range]))")
        (query "Blocked" (shareOf "BLOCKED"))
        (query "Cached" (shareOf "CACHED"))
        (query "Upstream p95" (upstreamP95 "le" "$__range"))
        (query "Errors" "sum(increase(blocky_error_total[$__range]))")
        (query "Blocklist entries" "max(sum by (host) (blocky_denylist_cache_entries))")
      ];
      defaults = count;
      overrides = [
        (byRefId "B" [
          {
            id = "unit";
            value = "percent";
          }
          {
            id = "decimals";
            value = 1;
          }
        ])
        (byRefId "C" [
          {
            id = "unit";
            value = "percent";
          }
        ])
        (byRefId "D" [
          {
            id = "unit";
            value = "s";
          }
        ])
        (byRefId "E" [
          {
            id = "color";
            value.mode = "thresholds";
          }
          {
            id = "thresholds";
            value = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "red";
                  value = 1;
                }
              ];
            };
          }
        ])
      ];
    })

    (row "Queries" 5)
    (overTime {
      title = "Queries per minute by result";
      gridPos = at 0 6 16 9;
      stacked = true;
      defaults.unit = "short";
      targets = [
        (query "{{response_type}}" "60 * sum by (response_type) (rate(${responses ""}[$__rate_interval]))")
      ];
    })
    (topBars "Top clients" (at 16 6 8 9) (
      query "{{client}}" (topClients "blocky_query_total{${realClients}}")
    ))

    (row "Blocking" 15)
    (topBars "Top blocked domains" (at 0 16 12 9) {
      datasource = loki;
      queryType = "instant";
      legendFormat = "{{domain}}";
      expr = ''sort_desc(topk(10, sum by (domain) (count_over_time({unit="blocky.service"} |= "response_type=BLOCKED" | regexp "question_name=(?P<domain>\\S+?)\\.? " [$__range]))))'';
    })
    (topBars "Most blocked clients" (at 12 16 12 9) (
      query "{{client}}" (topClients (responses '',response_type="BLOCKED"''))
    ))

    (row "Servers" 25)
    (panel {
      type = "state-timeline";
      title = "Answering";
      gridPos = at 0 26 24 4;
      targets = [ (query "{{host}}" ''probe_success{job="dns"}'') ];
      defaults = {
        color.mode = "thresholds";
        thresholds = {
          mode = "absolute";
          steps = [
            {
              color = "red";
              value = null;
            }
            {
              color = "green";
              value = 1;
            }
          ];
        };
        mappings = [
          {
            type = "value";
            options = {
              "0" = {
                text = "Down";
                index = 0;
              };
              "1" = {
                text = "Up";
                index = 1;
              };
            };
          }
        ];
      };
      options = {
        showValue = "never";
        mergeValues = true;
        rowHeight = 0.8;
        legend.showLegend = false;
        tooltip.mode = "single";
      };
    })
    (overTime {
      title = "Queries per minute by server";
      gridPos = at 0 30 12 9;
      defaults.unit = "short";
      targets = [
        (query "{{host}}" "60 * sum by (host) (rate(blocky_query_total{${realClients}}[$__rate_interval]))")
      ];
    })
    (overTime {
      title = "Lookup time";
      gridPos = at 12 30 12 9;
      defaults.unit = "s";
      targets = [
        (query "{{host}} upstream p95" (upstreamP95 "host, le" "$__rate_interval"))
        (query "{{host}} recursion avg" "unbound_recursion_time_seconds_avg")
      ];
    })
  ];
}
