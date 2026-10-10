{ nodes }:
let
  prometheus = "http://${nodes.monitoring.config.homelab.lanAddress}:9090/api/v1/query";
  realClients = import ../../../blocky/real-clients.nix { inherit nodes; };

  query = promql: {
    url = prometheus;
    parameters.query = promql;
  };
in
query ''probe_success{job="dns"}''
// {
  type = "custom-api";
  title = "DNS";
  cache = "1m";
  subrequests = {
    queries = query "sum(increase(blocky_query_total{${realClients}}[24h]))";
    blocked = query ''sum(increase(blocky_response_total{response_type="BLOCKED"}[24h]))'';
    per-host = query "sum by (host) (increase(blocky_query_total{${realClients}}[24h]))";
    blocklists = query "blocky_denylist_cache_entries";
  };
  template = builtins.readFile ./template.html;
}
