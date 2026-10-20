{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  package = pkgs.callPackage ./package.nix { };
  paperless = config.services.paperless;
  name = "paperless-gpt";
  port = 8080;
  stateDir = "/var/lib/${name}";
  db = "${stateDir}/db/modification_history.db";
  dumps = "${stateDir}/dumps";
  sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";
  model = "claude-haiku-5-5";
  clients = map (host: nodes.${host}.config.homelab.lanAddress) [
    "ingress"
    "dashboard"
  ];
in
{
  homelab = {
    secrets = [ "paperless-gpt-env" ];

    routes.papergpt = port;

    backup = {
      paths = [ stateDir ];
      exclude = [ "${db}*" ];
      prepare = ''
        if [ -e ${db} ]; then
          install -d -m 0700 ${dumps}
          ${sqlite3} ${db} ".backup '${dumps}/modification_history.db'"
        fi
      '';
    };

    monitoring.units = [ "${name}.service" ];
  };

  users.users.${name} = {
    isSystemUser = true;
    group = name;
    home = stateDir;
  };
  users.groups.${name} = { };

  systemd.services.${name} = {
    description = "paperless-gpt, re-OCRing Paperless documents with Claude";
    after = [
      "network-online.target"
      "paperless-web.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    restartTriggers = [ (builtins.hashFile "sha256" config.age.secrets.paperless-gpt-env.file) ];

    environment = {
      GIN_MODE = "release";
      LISTEN_INTERFACE = ":${toString port}";
      PAPERLESS_BASE_URL = "http://127.0.0.1:${toString paperless.port}";
      PAPERLESS_PUBLIC_URL = "https://${paperless.domain}";
      PAPERLESS_GPT_CACHE_DIR = "/var/cache/${name}";
      LLM_PROVIDER = "anthropic";
      LLM_MODEL = model;
      VISION_LLM_PROVIDER = "anthropic";
      VISION_LLM_MODEL = model;
      VISION_LLM_MAX_TOKENS = "16000";
      OCR_PROVIDER = "llm";
      OCR_PROCESS_MODE = "image";
      OCR_LIMIT_PAGES = "0";
      PDF_UPLOAD = "false";
      PDF_REPLACE = "false";
    };

    serviceConfig = {
      User = name;
      Group = name;
      WorkingDirectory = stateDir;
      StateDirectory = name;
      StateDirectoryMode = "0700";
      CacheDirectory = name;
      EnvironmentFile = config.age.secrets.paperless-gpt-env.path;
      ExecStartPre = "${lib.getExe' pkgs.coreutils "ln"} -sfn ${package}/share/${name}/default_prompts ${stateDir}/default_prompts";
      ExecStart = lib.getExe package;
      Restart = "on-failure";
      RestartSec = "10s";
      MemoryMax = "2G";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictNamespaces = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
    };
  };

  networking.firewall.extraCommands = lib.concatMapStrings (ip: ''
    iptables -A nixos-fw -p tcp -s ${ip} --dport ${toString port} -j nixos-fw-accept
  '') clients;
}
