let
  shane = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINfq31bP+xQwlO/joZeGU6LaLYZXV2ql7TLSv5ToVUtJ";
  inherit (import ./host-keys.nix)
    dashboard
    monitoring
    ingress
    dns1
    dns2
    plex
    arr
    brain
    auth
    forge
    builder
    dlna
    gym
    rss
    home
    photos
    paper
    ;
in
{
  "proxmox-token.age".publicKeys = [
    shane
    dashboard
  ];
  "healthchecks-ping.age".publicKeys = [
    shane
    monitoring
  ];
  "discord-webhook.age".publicKeys = [
    shane
    dashboard
    monitoring

  ];
  "unraid-smart-ssh-key.age".publicKeys = [
    shane
    monitoring
  ];
  "pve-exporter.age".publicKeys = [
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
  "linear-api-key.age".publicKeys = [
    shane
    dashboard
  ];
  "backup-dashboard.age".publicKeys = [
    shane
    dashboard
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
    dashboard
    monitoring
    ingress
    dns1
    dns2
    plex
    arr
    brain
    auth
    forge
    builder
    dlna
    gym
    rss
    home
    photos
    paper
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
  "backup-forge.age".publicKeys = [
    shane
    forge
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
  "zigbee2mqtt-secret.age".publicKeys = [
    shane
    home
  ];
  "forgejo-oidc-client-secret.age".publicKeys = [
    shane
    forge
  ];
  "immich-glance-api-key.age".publicKeys = [
    shane
    dashboard
  ];
  "unraid-api-key.age".publicKeys = [
    shane
    dashboard
  ];
  "forgejo-runner-secret.age".publicKeys = [
    shane
    forge
    builder
  ];
  "builder-ssh-key.age".publicKeys = [
    shane
    builder
  ];
  "nix-cache-signing-key.age".publicKeys = [
    shane
    builder
  ];
  "forge-bot-token.age".publicKeys = [
    shane
    builder
  ];
  "renovate-github-token.age".publicKeys = [
    shane
    builder
  ];
  "terraform-cloud-token.age".publicKeys = [
    shane
    builder
  ];
  "terraform-pve-token.age".publicKeys = [
    shane
    builder
  ];
  "terraform-hcloud-token.age".publicKeys = [
    shane
    builder
  ];
  "terraform-cloudflare-token.age".publicKeys = [
    shane
    builder
  ];
  "terraform-access-emails.age".publicKeys = [
    shane
    builder
  ];
  "terraform-forgejo-token.age".publicKeys = [
    shane
    builder
  ];
  "terraform-unifi-token.age".publicKeys = [
    shane
    builder
  ];
  "backup-r2-dashboard.age".publicKeys = [
    shane
    dashboard
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
  "backup-r2-forge.age".publicKeys = [
    shane
    forge
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
  "cloudflare-r2-usage.age".publicKeys = [
    shane
    monitoring
  ];
}
