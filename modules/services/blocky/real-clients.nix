{ nodes }:
let
  monitoring = nodes.monitoring.config.homelab.lanAddress;
in
''client!~"127.0.0.1|localhost|${monitoring}|monitoring"''
