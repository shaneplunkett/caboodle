{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:
let
  cfg = config.services.forgejo;
  secrets = config.age.secrets;
  exe = lib.getExe cfg.package;
  runuser = lib.getExe' pkgs.util-linux "runuser";
  postgres = config.services.postgresql.finalPackage;
  dumps = "/var/backup/forgejo";
  dump = "${dumps}/forgejo.dump";
  source = "pocket-id";

  forgejo17 =
    (pkgs.callPackage (import "${pkgs.path}/pkgs/by-name/fo/forgejo/generic.nix" {
      version = "17.0.0";
      hash = "sha256-uEl0a1+NOKpSal0fUyy8n1Ng8Vc+NUsEkWEXo9Az4W0=";
      npmDepsHash = "sha256-Zff93AC+zTACatAOdjtKt5luMmTOM5C3+2Y0BsVUf6A=";
      vendorHash = "sha256-vXjsZ08eez3oiLL2Um+uFX9YbrRnbq8q5Pj/P3mZTeY=";
    }) { }).overrideAttrs
      (old: {
        checkFlags = map (flag: flag + "|^TestActivityPubMatchesList$") old.checkFlags;
      });

  env = {
    USER = cfg.user;
    HOME = cfg.stateDir;
    FORGEJO_WORK_DIR = cfg.stateDir;
    FORGEJO_CUSTOM = cfg.customDir;
  };

  admin = pkgs.writeShellScriptBin "forgejo-admin" ''
    exec ${runuser} -u ${cfg.user} -- ${lib.getExe' pkgs.coreutils "env"} \
      ${lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "${name}=${value}") env)} \
      ${exe} admin "$@"
  '';

  oidc = pkgs.writeShellScript "forgejo-oidc" ''
    secret="$(< "$CREDENTIALS_DIRECTORY/secret")"
    id="$(${exe} admin auth list | ${lib.getExe pkgs.gawk} '$2 == "${source}" { print $1 }')"
    set -- --name ${source} --provider openidConnect --key forgejo --secret "$secret" \
      --auto-discover-url https://auth.shaneplunkett.com/.well-known/openid-configuration \
      --scopes email --scopes profile --scopes groups \
      --group-claim-name groups --admin-group forgejo_admins --skip-local-2fa
    if [ -n "$id" ]; then
      exec ${exe} admin auth update-oauth --id "$id" "$@"
    fi
    exec ${exe} admin auth add-oauth "$@"
  '';

  register = pkgs.writeShellScript "forgejo-runner-register" ''
    exec ${exe} forgejo-cli actions register --name builder --keep-labels \
      --secret-file "$CREDENTIALS_DIRECTORY/secret"
  '';

  oneshot = credential: script: {
    after = [ "forgejo.service" ];
    requires = [ "forgejo.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = env;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = cfg.user;
      LoadCredential = "secret:${credential}";
      ExecStart = script;
    };
  };
in
{
  imports = [ ./workflows.nix ];

  homelab = {
    secrets = [
      "forgejo-oidc-client-secret"
      "forgejo-runner-secret"
    ];

    routes.git = cfg.settings.server.HTTP_PORT;

    oidcClients.forgejo = {
      name = "Forgejo";
      callbackURLs = [ "https://git.shaneplunkett.com/user/oauth2/pocket-id/callback" ];
      pkce = false;
      groups = [ "forgejo_admins" ];
    };

    monitoring.units = [
      "forgejo.service"
      "postgresql.service"
    ];

    backup = {
      paths = [
        cfg.stateDir
        dumps
      ];
      prepare = ''
        ${runuser} -u postgres -- \
          ${postgres}/bin/pg_dump -Fc -Z0 -d ${cfg.database.name} -f ${dump}.tmp
        mv ${dump}.tmp ${dump}
      '';
    };
  };

  services.forgejo = {
    enable = true;
    package = forgejo17;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = "git.shaneplunkett.com";
        ROOT_URL = "https://git.shaneplunkett.com/";
        SSH_DOMAIN = "forge";
      };
      security.REVERSE_PROXY_TRUSTED_PROXIES = nodes.ingress.config.homelab.lanAddress;
      session = {
        PROVIDER = "db";
        COOKIE_SECURE = true;
      };
      service = {
        REQUIRE_SIGNIN_VIEW = true;
        ALLOW_ONLY_EXTERNAL_REGISTRATION = true;
        SHOW_REGISTRATION_BUTTON = false;
        DEFAULT_KEEP_EMAIL_PRIVATE = true;
      };
      openid.ENABLE_OPENID_SIGNIN = false;
      oauth2_client = {
        ENABLE_AUTO_REGISTRATION = true;
        USERNAME = "preferred_username";
      };
      "repository.pull-request" = {
        DEFAULT_MERGE_STYLE = "rebase";
        DEFAULT_UPDATE_STYLE = "rebase";
      };
      actions.ENABLED = true;
    };
  };

  systemd.services = {
    forgejo-oidc = oneshot secrets.forgejo-oidc-client-secret.path oidc;
    forgejo-runner-register = oneshot secrets.forgejo-runner-secret.path register;
  };

  systemd.tmpfiles.rules = [ "d ${dumps} 0700 postgres postgres -" ];

  environment.systemPackages = [ admin ];

  networking.firewall.allowedTCPPorts = [ cfg.settings.server.HTTP_PORT ];
}
