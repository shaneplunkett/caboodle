{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  cfg = config.services.pocket-id;
  secrets = config.age.secrets;
  sqlite3 = lib.getExe' pkgs.sqlite "sqlite3";
  db = "${cfg.dataDir}/data/pocket-id.db";
  dumps = "${cfg.dataDir}/dumps";

  clients = lib.concatMapAttrs (_: node: node.config.homelab.oidcClients) nodes;
  clientIds = lib.concatMap (node: lib.attrNames node.config.homelab.oidcClients) (
    lib.attrValues nodes
  );
  clientSecrets = lib.unique (
    lib.filter (secret: secret != null) (lib.catAttrs "secret" (lib.attrValues clients))
  );
  clientsFile = pkgs.writeText "pocket-id-clients.json" (builtins.toJSON clients);
  reconcile = pkgs.writeShellApplication {
    name = "pocket-id-clients";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = builtins.readFile ./clients.sh;
  };

  recover = pkgs.writeShellScriptBin "pocket-id-recover" ''
    cd ${cfg.dataDir}
    export APP_URL=${cfg.settings.APP_URL}
    ENCRYPTION_KEY="$(cat ${secrets.pocket-id-encryption-key.path})"
    export ENCRYPTION_KEY
    exec ${lib.getExe' pkgs.util-linux "runuser"} -u ${cfg.user} -- ${lib.getExe cfg.package} one-time-access-token "$@"
  '';
in
{
  homelab = {
    secrets = [
      "pocket-id-encryption-key"
      "pocket-id-api-key"
    ]
    ++ clientSecrets;
    monitoring.units = [ "pocket-id-clients.service" ];

    oidcClients = {
      proxmox = {
        name = "Proxmox";
        callbackURLs = [ "https://proxmox.shaneplunkett.com" ];
        launchURL = "https://proxmox.shaneplunkett.com";
        pkce = false;
        groups = [ "proxmox_admins" ];
      };
    };
  };

  assertions = [
    {
      assertion = lib.allUnique clientIds;
      message = "Two hosts declare the same Pocket ID client: ${toString clientIds}";
    }
  ];

  systemd.services.pocket-id-clients = {
    description = "Make Pocket ID's clients match homelab.oidcClients";
    after = [ "pocket-id.service" ];
    requires = [ "pocket-id.service" ];
    wantedBy = [ "multi-user.target" ];
    environment.POCKET_ID_URL = "http://127.0.0.1:${toString cfg.settings.PORT}";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      DynamicUser = true;
      ExecStart = "${lib.getExe reconcile} apply ${clientsFile}";
      LoadCredential = [
        "api-key:${secrets.pocket-id-api-key.path}"
      ]
      ++ map (secret: "${secret}:${secrets.${secret}.path}") clientSecrets;
    };
  };

  homelab.routes.auth = cfg.settings.PORT;

  services.pocket-id = {
    enable = true;
    credentials.ENCRYPTION_KEY = secrets.pocket-id-encryption-key.path;
    settings = {
      APP_URL = "https://auth.shaneplunkett.com";
      PORT = 1411;
      TRUST_PROXY = true;
      ANALYTICS_DISABLED = true;
    };
  };

  homelab.backup = {
    paths = [ cfg.dataDir ];
    exclude = [ "${db}*" ];
    prepare = ''
      if [ -e ${db} ]; then
        install -d -m 0700 ${dumps}
        ${sqlite3} ${db} ".backup '${dumps}/pocket-id.db'"
      fi
    '';
  };

  environment.systemPackages = [ recover ];

  networking.firewall.allowedTCPPorts = [ cfg.settings.PORT ];
}
