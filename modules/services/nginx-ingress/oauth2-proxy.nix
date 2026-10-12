{ config, ... }:
let
  secrets = config.age.secrets;
  cfg = config.services.oauth2-proxy;
in
{
  homelab = {
    secrets = [
      "oauth2-proxy-client-secret"
      "oauth2-proxy-cookie-secret"
    ];

    oidcClients.${cfg.clientID} = {
      name = "Media";
      callbackURLs = [ cfg.redirectURL ];
      groups = [ "media_admins" ];
    };
  };

  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://auth.shaneplunkett.com";
    clientID = "bcea19ae-7c50-4190-86a9-0f6d20afefd6";
    clientSecretFile = secrets.oauth2-proxy-client-secret.path;
    scope = "openid email profile groups";
    redirectURL = "https://${cfg.nginx.domain}/oauth2/callback";
    email.domains = [ "*" ];
    upstream = "static://202";
    reverseProxy = true;
    trustedProxyIP = [ "127.0.0.1/32" ];
    setXauthrequest = true;
    cookie = {
      domain = ".shaneplunkett.com";
      secretFile = secrets.oauth2-proxy-cookie-secret.path;
      expire = "720h0m0s";
    };
    extraConfig = {
      whitelist-domain = ".shaneplunkett.com";
      code-challenge-method = "S256";
      skip-provider-button = true;
      insecure-oidc-allow-unverified-email = true;
    };
  };
}
