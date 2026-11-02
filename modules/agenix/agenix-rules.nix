let
  shane = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ";
  inherit (import ./host-keys.nix)
    monitoring
    ingress
    dns1
    dns2
    plex
    arr
    brain
    auth
    dlna
    gym
    rss
    home
    photos
    paper
    music
    recipes
    mirror
    pve
    cube
    desktop
    mini
    ;
in
{
  "healthchecks-ping.age".publicKeys = [
    shane
    monitoring
  ];
  "discord-webhook.age".publicKeys = [
    shane
    monitoring

  ];
  "unpoller-api-key.age".publicKeys = [
    shane
    monitoring
  ];
  "grafana-admin-password.age".publicKeys = [
    shane
    monitoring

  ];
  "grafana-secret-key.age".publicKeys = [
    shane
    monitoring

  ];
  "cloudflare-dns.age".publicKeys = [
    shane
    ingress

  ];
  "backup-plex.age".publicKeys = [
    shane
    plex
  ];
  "backup-arr.age".publicKeys = [
    shane
    arr
  ];
  "hetzner-api-token.age".publicKeys = [
    shane
    monitoring
  ];
  "sonarr.age".publicKeys = [
    shane
    arr
  ];
  "sonarr-anime.age".publicKeys = [
    shane
    arr
  ];
  "radarr.age".publicKeys = [
    shane
    arr
  ];
  "prowlarr.age".publicKeys = [
    shane
    arr
  ];
  "sabnzbd.age".publicKeys = [
    shane
    arr
  ];
  "deluge-auth.age".publicKeys = [
    shane
    arr
  ];
  "tailscale-oauth.age".publicKeys = [
    shane
    monitoring
    ingress
    dns1
    dns2
    plex
    arr
    brain
    auth
    dlna
    gym
    rss
    home
    photos
    paper
    music
    recipes
    mirror
    pve
    cube
  ];
  "backup-brain.age".publicKeys = [
    shane
    brain
  ];
  "vex-brain.age".publicKeys = [
    shane
    brain
  ];
  "cloudflared-brain.age".publicKeys = [
    shane
    brain
  ];
  "backup-auth.age".publicKeys = [
    shane
    auth
  ];
  "pocket-id-encryption-key.age".publicKeys = [
    shane
    auth
  ];
  "pocket-id-api-key.age".publicKeys = [
    shane
    auth
  ];
  "grafana-oidc-client-secret.age".publicKeys = [
    shane
    monitoring
  ];
  "oauth2-proxy-client-secret.age".publicKeys = [
    shane
    ingress
  ];
  "oauth2-proxy-cookie-secret.age".publicKeys = [
    shane
    ingress
  ];
  "backup-gym.age".publicKeys = [
    shane
    gym
  ];
  "backup-rss.age".publicKeys = [
    shane
    rss
  ];
  "backup-home.age".publicKeys = [
    shane
    home
  ];
  "backup-photos.age".publicKeys = [
    shane
    photos
  ];
  "immich-oidc-client-secret.age".publicKeys = [
    shane
    photos
  ];
  "backup-paper.age".publicKeys = [
    shane
    paper
  ];
  "paperless-oidc-client-secret.age".publicKeys = [
    shane
    paper
    auth
  ];
  "paperless-env.age".publicKeys = [
    shane
    paper
  ];
  "paperless-gpt-env.age".publicKeys = [
    shane
    paper
  ];
  "zigbee2mqtt-secret.age".publicKeys = [
    shane
    home
  ];
  "github-app-client-id.age".publicKeys = [
    shane
    mirror
  ];
  "github-app-private-key.age".publicKeys = [
    shane
    mirror
  ];
  "github-inputs-token.age".publicKeys = [
    shane
  ];
  "terraform-cloud-token.age".publicKeys = [
    shane
  ];
  "terraform-hcloud-token.age".publicKeys = [
    shane
  ];
  "terraform-cloudflare-token.age".publicKeys = [
    shane
  ];
  "terraform-access-emails.age".publicKeys = [
    shane
  ];
  "terraform-unifi-token.age".publicKeys = [
    shane
  ];
  "terraform-incus-key.age".publicKeys = [
    shane
  ];
  "backup-r2-plex.age".publicKeys = [
    shane
    plex
  ];
  "backup-r2-arr.age".publicKeys = [
    shane
    arr
  ];
  "backup-r2-brain.age".publicKeys = [
    shane
    brain
  ];
  "backup-r2-auth.age".publicKeys = [
    shane
    auth
  ];
  "backup-r2-gym.age".publicKeys = [
    shane
    gym
  ];
  "backup-r2-rss.age".publicKeys = [
    shane
    rss
  ];
  "backup-r2-home.age".publicKeys = [
    shane
    home
  ];
  "backup-r2-photos.age".publicKeys = [
    shane
    photos
  ];
  "backup-r2-paper.age".publicKeys = [
    shane
    paper
  ];
  "backup-music.age".publicKeys = [
    shane
    music
  ];
  "backup-r2-music.age".publicKeys = [
    shane
    music
  ];
  "aurral-oidc-client-secret.age".publicKeys = [
    shane
    music
    auth
  ];
  "aurral-env.age".publicKeys = [
    shane
    music
  ];
  "backup-recipes.age".publicKeys = [
    shane
    recipes
  ];
  "backup-r2-recipes.age".publicKeys = [
    shane
    recipes
  ];
  "backup-mirror.age".publicKeys = [
    shane
    mirror
  ];
  "backup-r2-mirror.age".publicKeys = [
    shane
    mirror
  ];
  "norish-oidc-client-secret.age".publicKeys = [
    shane
    recipes
    auth
  ];
  "norish-env.age".publicKeys = [
    shane
    recipes
  ];
  "norish-obscura-env.age".publicKeys = [
    shane
    recipes
  ];
  "nix-store-key-desktop.age".publicKeys = [
    shane
    desktop
  ];
  "nix-store-key-mini.age".publicKeys = [
    shane
    mini
  ];
}
