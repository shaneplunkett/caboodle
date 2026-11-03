{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.linearBridge;
  package = pkgs.callPackage ../../../pkgs/linear-bridge { };
  secret = config.age.secrets.linear-bridge;
  pingSecret = config.age.secrets.healthchecks-ping;
  idOption =
    description: default:
    lib.mkOption {
      type = lib.types.str;
      inherit default description;
    };
in
{
  options.homelab.linearBridge = {
    port = lib.mkOption {
      type = lib.types.port;
      default = 9096;
      description = "Port the bridge listens on for alerts, on every address in listenAddresses.";
    };

    listenAddresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "127.0.0.1" ];
      description = "IP addresses the bridge listens on. Alertmanager posts to 127.0.0.1, so that one stays.";
    };

    allowedSources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "LAN addresses the firewall lets post to the bridge. Only these and loopback can reach it. The bridge has no login, so anything that reaches it can file an urgent issue, and the gateway forwards nothing here.";
    };

    teamId = idOption "Linear team that alert issues are filed in." "8077af69-b056-42f3-b094-9fdc1d2fa76d";
    assigneeId = idOption "Linear user that alert issues are assigned to." "18195904-2fce-48c4-888b-270e2ad8a01f";
    stateId = idOption "Linear workflow state that alert issues start in." "6e8b1699-7b5f-4d91-9425-a9e5e981d2d8";

    labelIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "814b39ce-442a-40ff-a02d-5734070605a7"
        "86fb88ad-6bcc-459a-88cf-0ba9584cf6e3"
        "73d9c3bb-981b-458f-b862-1f1de433f341"
      ];
      description = "Linear labels on every alert issue: bug, needs-triage and repo:caboodle.";
    };

    watchdogAlert = lib.mkOption {
      type = lib.types.str;
      default = "Watchdog";
      description = "Alert that pings healthchecks.io instead of becoming an issue.";
    };
  };

  config = {
    homelab.secrets = [
      "linear-bridge"
      "healthchecks-ping"
    ];

    networking.firewall.extraCommands = lib.concatMapStrings (source: ''
      iptables -A nixos-fw -p tcp -s ${source} --dport ${toString cfg.port} -j nixos-fw-accept
    '') cfg.allowedSources;

    systemd.services.linear-bridge = {
      description = "Files Alertmanager's alerts as Linear issues";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = map (s: builtins.hashFile "sha256" s.file) [
        secret
        pingSecret
      ];

      environment = {
        BRIDGE_PORT = toString cfg.port;
        BRIDGE_LISTEN_ADDRESSES = lib.concatStringsSep "," cfg.listenAddresses;
        BRIDGE_ALERTS_PAGE = "${config.services.prometheus.webExternalUrl}/alerts";
        BRIDGE_WATCHDOG_ALERT = cfg.watchdogAlert;
        LINEAR_TEAM_ID = cfg.teamId;
        LINEAR_ASSIGNEE_ID = cfg.assigneeId;
        LINEAR_STATE_ID = cfg.stateId;
        LINEAR_LABEL_IDS = lib.concatStringsSep "," cfg.labelIds;
      };

      serviceConfig = {
        DynamicUser = true;
        EnvironmentFile = [
          secret.path
          pingSecret.path
        ];
        ExecStart = lib.getExe package;
        Restart = "on-failure";
        RestartSec = "10s";
        MemoryMax = "128M";
        ProtectHome = true;
        PrivateDevices = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        CapabilityBoundingSet = "";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };
  };
}
