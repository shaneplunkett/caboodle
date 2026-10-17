{ lib }:
let
  panels = import ./panels.nix { inherit lib; };
  inherit (panels)
    at
    query
    panel
    stat
    bars
    dashboard
    ;

  overTime =
    args: lib.recursiveUpdate (panels.overTime args) { fieldConfig.defaults.custom.axisWidth = 70; };

  gateway = ''name="Cloud Gateway Max"'';
  wan = ''wan_networkgroup="WAN"'';
  plan = 500;
  side = 6;
  main = 24 - side;

  fixed = color: {
    mode = "fixed";
    fixedColor = color;
  };

  againstPlan = {
    unit = "Mbits";
    decimals = 0;
    color.mode = "thresholds";
    thresholds = {
      mode = "absolute";
      steps = [
        {
          color = "red";
          value = null;
        }
        {
          color = "orange";
          value = plan * 0.8;
        }
        {
          color = "green";
          value = plan * 0.95;
        }
      ];
    };
  };

  bitsPerSecond = counter: "sum(rate(${counter}[$__rate_interval])) * 8";
  deviceRate =
    range:
    "sum by (name) (rate(unpoller_client_receive_bytes_total${range}) + rate(unpoller_client_transmit_bytes_total${range}))";
in
dashboard {
  uid = "internet";
  title = "Internet";
  panels = [
    (lib.recursiveUpdate (stat {
      title = "Connected for";
      gridPos = at 0 0 side 4;
      targets = [ (query "" "unpoller_device_uplink_uptime_seconds{${gateway}}") ];
      defaults = {
        unit = "s";
        decimals = 1;
        color = fixed "text";
      };
    }) { options.textMode = "value"; })
    (panel {
      type = "state-timeline";
      title = "Up or down";
      gridPos = at side 0 main 4;
      targets = [ (query "Internet" "max(unpoller_wan_interface_state{${wan}})") ];
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
              "0".text = "Down";
              "1".text = "Up";
            };
          }
        ];
      };
      options = {
        showValue = "never";
        mergeValues = true;
        rowHeight = 0.8;
        legend.showLegend = false;
      };
    })

    (stat {
      title = "Last speed test (plan ${toString plan}/${toString plan})";
      gridPos = at 0 4 side 8;
      targets = [
        (query "Down" "unpoller_device_speedtest_download{${gateway}}")
        (query "Up" "unpoller_device_speedtest_upload{${gateway}}")
      ];
      defaults = againstPlan;
    })
    (overTime {
      title = "Latency";
      gridPos = at side 4 main 8;
      targets = [ (query "Gateway to internet" "unpoller_device_uplink_latency_seconds{${gateway}}") ];
      defaults = {
        unit = "s";
        min = 0;
        color = fixed "blue";
      };
    })

    (overTime {
      title = "Internet usage";
      gridPos = at side 12 main 8;
      targets = [
        (query "Download" (bitsPerSecond "unpoller_device_wan_receive_bytes_total{${gateway}}"))
        (query "Upload" (bitsPerSecond "unpoller_device_wan_transmit_bytes_total{${gateway}}"))
      ];
      defaults = {
        unit = "bps";
        min = 0;
      };
    })

    (overTime {
      title = "Busiest devices (all traffic, including inside the house)";
      gridPos = at side 20 main 10;
      targets = [
        (query "{{name}}" "(${deviceRate "[$__rate_interval]"} * 8) and on (name) topk(5, ${deviceRate "[$__range] @ end()"})")
      ];
      defaults = {
        unit = "bps";
        min = 0;
      };
    })
    (lib.recursiveUpdate
      (bars {
        title = "Top internet users, last month or so";
        gridPos = at 0 12 side 18;
        targets = [
          (query "{{name}}" ''sort_desc(topk(10, sum by (name) (unpoller_client_dpi_receive_bytes{name!="TOTAL"} + unpoller_client_dpi_transmit_bytes{name!="TOTAL"})))'')
        ];
        defaults = {
          unit = "decbytes";
          min = 0;
          color = fixed "purple";
        };
      })
      {
        options = {
          namePlacement = "top";
          text = {
            titleSize = 13;
            valueSize = 13;
          };
        };
      }
    )
  ];
}
