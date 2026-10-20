{
  config,
  lib,
  nodes,
  ...
}:
let
  cfg = config.services.paperless;
  secrets = config.age.secrets;
  envHash = builtins.hashFile "sha256" secrets.paperless-env.file;
in
{
  homelab = {
    secrets = [
      "paperless-oidc-client-secret"
      "paperless-env"
    ];

    routes.paper = cfg.port;

    oidcClients.paperless = {
      name = "Paperless";
      callbackURLs = [ "https://${cfg.domain}/accounts/oidc/pocket-id/login/callback/" ];
      launchURL = "https://${cfg.domain}/";
      groups = [ "paperless_admins" ];
      secret = "paperless-oidc-client-secret";
    };

    backup = {
      paths = [ cfg.exporter.directory ];
      prepare = "systemctl start --wait paperless-exporter.service";
    };

    monitoring.units = [
      "paperless-web.service"
      "paperless-consumer.service"
      "paperless-scheduler.service"
      "paperless-task-queue.service"
      "postgresql.service"
      "redis-paperless.service"
      "tika.service"
      "gotenberg.service"
    ];
  };

  age.secrets.paperless-env.owner = cfg.user;

  services.paperless = {
    enable = true;
    address = "0.0.0.0";
    domain = "paper.shaneplunkett.com";
    database.createLocally = true;
    configureTika = true;
    environmentFile = secrets.paperless-env.path;

    exporter = {
      enable = true;
      onCalendar = null;
    };

    settings = {
      PAPERLESS_TIME_ZONE = "Australia/Melbourne";
      PAPERLESS_OCR_LANGUAGE = "eng";
      PAPERLESS_TRUSTED_PROXIES = nodes.ingress.config.homelab.lanAddress;

      PAPERLESS_APPS = "allauth.socialaccount.providers.openid_connect";
      PAPERLESS_DISABLE_REGULAR_LOGIN = true;
      PAPERLESS_REDIRECT_LOGIN_TO_SSO = true;
      PAPERLESS_ACCOUNT_ALLOW_SIGNUPS = false;
      PAPERLESS_SOCIAL_AUTO_SIGNUP = true;
      PAPERLESS_SOCIAL_ACCOUNT_SYNC_SUPERUSER_GROUP = "paperless_admins";

      PAPERLESS_AI_ENABLED = true;
      PAPERLESS_AI_LLM_BACKEND = "openai-like";
      PAPERLESS_AI_LLM_ENDPOINT = "https://api.anthropic.com/v1/";
      PAPERLESS_AI_LLM_MODEL = "claude-haiku-5-5";
      PAPERLESS_AI_LLM_EXTRA_PARAMS = {
        temperature = 1;
        max_tokens = 16000;
      };
      PAPERLESS_AI_LLM_EMBEDDING_BACKEND = "openai-like";
      PAPERLESS_AI_LLM_EMBEDDING_ENDPOINT = "https://api.openai.com/v1";
      PAPERLESS_AI_LLM_EMBEDDING_MODEL = "text-embedding-3-small";
    };
  };

  systemd.services =
    lib.genAttrs
      [
        "paperless-web"
        "paperless-consumer"
        "paperless-scheduler"
        "paperless-task-queue"
      ]
      (_: {
        restartTriggers = [ envHash ];
      });

  networking.firewall.allowedTCPPorts = [ cfg.port ];
}
