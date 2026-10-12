# Immich for photos

A proposal for moving Shane's photos off iCloud and into Immich, a
self-hosted photo library with an iPhone app that backs up the camera roll.
A research agent did the first pass, then Shane and Vex settled the open
questions. Claims
cite the sources list at the bottom, and anything unconfirmed says so. It was
checked against Immich 3.3.1, which was both the latest release [1] and the
version in the flake's nixpkgs at the time.

## Decisions

- **Run the nixpkgs `services.immich` module** in a new LXC on cube, not the
  official containers.
- **Keep everything on cube's local NVMe.** Originals, database and
  thumbnails all live in the container. Nothing goes on Unraid.
- **Back up the whole media folder offsite with restic,** to the existing
  Storage Box, through `homelab.backup.paths`. The library is small next to
  the box.
- **CPU for machine learning and video.** The UHD 630 can come later if it's
  ever needed.
- **Import with the Immich iPhone app,** everything in one go, then the
  Google Takeout. Sorting into albums happens in Immich afterwards.
- **iCloud Photos stays on** as a third copy for now.
- **Sign-in is Pocket ID through Immich's own OAuth,** with auto-launch.
  Away from home is Tailscale.
- **Nix owns Immich's settings,** so the OAuth secret comes from agenix.
  Every settings change is a PR.
- **The route is `photos`,** and Shane is the only user for now. Family
  might get accounts one day.

## 1. What Immich is like now

### What it does well

- Phone backup that dedupes by checksum, and can mirror iPhone albums as
  Immich albums [19].
- Face recognition, and CLIP search, so "dog on a beach" finds dog photos
  with no tags [40][41].
- Maps, memories, partner sharing, shared albums, duplicate detection, OCR
  and non-destructive editing [3][39][42][43].
- Live Photos keep their video half, because the app uploads both parts [21].
  HEIC and RAW are supported formats [44].
- External libraries index folders Immich doesn't own [36]. Not needed here.

### Rough edges

- **It moves fast.** v2.0.0 was the first "stable" release, in October 2025
  [2]. v3.0.0 landed in July 2026 with a long list of breaking changes,
  though most of them hit API users rather than people running the app [3].
  Minor releases come about monthly, now with release candidates first.
- **Updates are one-way.** Database migrations run on start, so the rollback
  is a restore. Read the release notes in each flake update PR that bumps
  Immich.
- **Several features are still previews:** workflows and real-time HLS
  transcoding [3]. Hardware transcoding and ML acceleration are labelled
  experimental [12][13].
- **iOS decides when background backup runs,** not Immich [19][20]. v3 made
  the iOS background task start uploading sooner [3], but opening the app is
  still the reliable trigger.
- v3 dropped editing Live Photos in the mobile editor [3].

## 2. How it runs

**The nixpkgs module.** It fits well here, unlike Home Assistant's.

What it does for us [6]:

- Runs Postgres with pgvector and VectorChord, preloads `vchord.so`, and
  reindexes the vector indexes when VectorChord updates. Immich's docs make
  that a manual step for anyone running their own Postgres [10].
- Runs Redis on a unix socket, and the ML service next to the server.
- Takes secrets in `settings` as `{ _secret = <path>; }`, filled in at
  start from systemd credentials. That's how the OAuth client secret gets in
  from agenix.
- Has `accelerationDevices` for passing `/dev/dri/renderD128` through.

Why not the official containers:

- Immich says Docker inside an LXC isn't recommended [5]. Podman in an LXC
  works for Home Assistant, but Immich is four containers, one of them
  Immich's own Postgres image [11]. That's a pet database inside a pet
  container.
- Renovate would have to bump server and ML together, and keep the Postgres
  image matching.
- The module keeps up with upstream. nixpkgs had 3.3.1 two days after
  release, and every 3.x release landed within a couple of days [7].

What the module costs:

- No OpenVINO, CUDA or ROCm. The nixpkgs ML package is CPU-only [8], while
  upstream builds those as image variants [9]. That's fine on this hardware
  (section 3).
- Immich's docs and support assume Docker Compose. Paths and commands need
  translating.

### Settings

- Setting `services.immich.settings` writes Immich's config file. While a
  config file is set, nothing in Immich's admin settings can be edited in the
  UI [15]. Changes become a PR.
- The upside is that the OAuth secret stays in agenix, out of the database,
  and the config is reviewable. It matches how the rest of the homelab works.

## 3. Where it runs

**A new LXC on cube, on the nvme-thin pool.**

- cube is the always-on node, and phone backup belongs with Plex rather than
  with pve's experiments.
- cube's `nvme-thin` pool has the room. The `nixos-lxc` module hard-codes
  `local-lvm` for the root disk, so it needs a `datastore` variable first.
- The i7-8700 is plenty for ML at this library size. Immich's ML needs
  x86-64-v2 since v3 [5], which the 8700 has.
- Remote ML on pve's Ryzen is possible [38], but not worth a second moving
  part for a library this size.

### Sizing

- 4 cores, 8 GB of memory and 1 GB of swap. Immich wants at least 6 GB and
  recommends 8 GB [5]. An LXC's memory is a cap, not a reservation.
- About 250 GB of disk. Thumbnails and transcodes add 10 to 20% on top of the
  originals [5], and the pool is thin, so unused space isn't taken.

### Storage

**Everything local.** `mediaLocation` stays at `/var/lib/immich`, and
Postgres at `/var/lib/postgresql`, both on the container's NVMe disk.

Why not originals on an Unraid share:

- The database must never sit on a network share [5], so Unraid could only
  ever hold part of it.
- Unraid shares go stale on cube whenever Unraid restarts
  (`docs/cube/README.md`). Immich would refuse to start without its `.immich`
  marker files [17], which is the right failure, but it means a dead phone
  backup until someone remounts.
- The backup module refuses paths under `/mnt`, so originals on Unraid would
  need their own offsite plan. Local, they're one line in
  `homelab.backup.paths`.
- Splitting `upload/` and `library/` across mounts is something Immich
  advises against [16].

If the library ever outgrows the NVMe, Immich supports moving the big
folders to other storage [16]. That's a later problem.

### The iGPU, later

Plex uses the UHD 630 too, and a render node can be shared. It isn't needed
now:

- Only video transcoding would use it. Immich says hardware encodes are
  bigger and lower quality than software ones at the same settings [12].
- OpenVINO for ML is aimed at Iris Xe and Arc, and older iGPUs have more
  problems [13]. nixpkgs doesn't build it anyway [8].
- If real-time transcoding ever matters, use VAAPI with
  `intel-media-driver`. QSV on 8th-gen chips needs the old Media SDK runtime,
  which nixpkgs marks as having known vulnerabilities [14]. UNCONFIRMED
  whether jellyfin-ffmpeg's QSV path needs it on this chip.

## 4. Getting photos in

**The Immich iPhone app does the import.**

- With all albums selected, the app downloads each iCloud original that isn't
  on the phone, uploads it, then deletes the temporary copy [19][21].
- It uploads both halves of a Live Photo [21], and album sync recreates
  iPhone albums in Immich [19].
- Do the first run at home on Wi-Fi, plugged in, with the app open. iOS
  won't give a background task long enough for the whole library [20].
- **Edits:** 3.3 stacks an edit made outside Immich on top of its original
  [4]. UNCONFIRMED whether the app uploads Apple Photos' unedited original as
  well. Check with one edited photo before the full run.

The other routes, and why not:

- **Apple's data copy** (privacy.apple.com) gives originals in their original
  formats, with a 14-day window to download [22]. immich-go's `from-icloud`
  reads it, albums and memories included [23]. It's the better path for a
  big library. Here it's worth keeping as a cold archive on Unraid, not as
  the import.
- **icloudpd** needs Advanced Data Protection turned off and web access to
  iCloud on, and is looking for a maintainer [24].
- **Photos on a Mac or iCloud for Windows** both need the whole library
  downloaded to a computer first. The app route skips that.

### The Google Takeout

Shane has an old Google Photos Takeout that overlaps with iCloud.
**immich-go's `from-google-photos` imports it, after the iPhone run.**

- It reads the Takeout zips directly and takes dates, places, descriptions
  and people from Google's JSON sidecars. It recreates Google albums too
  [45][46].
- Trashed photos stay out by default, and so do files with no JSON
  [45]. Do a dry run first and look at what it would skip.
- Exact copies are skipped. immich-go compares checksums with what's
  already on the server, so re-running it after an interruption is safe
  [46].
- Copies Google compressed won't match by checksum. Storage saver shrinks
  photos over 16 MP, re-encodes some to JPEG and resizes video over 1080p
  [47]. Those land as near-duplicates.
- **Immich's duplicates utility catches near-duplicates** with ML. It
  preselects the bigger file with more EXIF to keep, then moves albums,
  favourites and tags onto it [43]. The iPhone originals are bigger, so they
  win, which is why the iCloud import goes first.

Run it from a laptop or the photos host, with an API key made in Immich.
The zips can sit on Unraid until it's done.

### Ongoing backup

- The app keeps backing up from then on. It uploads on Wi-Fi only by
  default [19], so most uploads happen at home.
- Turn on Background App Refresh for Immich and keep Low Power Mode off when
  possible [20].
- Keep iCloud Photos on. It's a third copy, next to Immich and the Storage
  Box.

## 5. Backups

**restic to the existing Storage Box, through the backup module.**

- Back up the whole `mediaLocation`. Immich recommends that [18], and it
  makes a restore usable straight away. Only `library/`, `upload/` and
  `profile/` are irreplaceable [18], so `thumbs/` and `encoded-video/` are
  the first things to exclude if the box ever gets tight.
- Immich dumps its database into `backups/` every night at 2am and keeps 14
  [18]. restic runs at 3am plus up to an hour, so it picks up a fresh dump.
  Set `backup.database.cronExpression` in the Nix settings so that order is
  written down.
- Don't back up Postgres's live files. The dump is the database backup.
- The prune policy keeps monthlies for six months, so a photo deleted by
  mistake can still be found after Immich's 30-day trash empties.
- The new host needs its own Storage Box subaccount and `backup-<host>`
  secret (`docs/hetzner/README.md`).

### Restoring

1. Rebuild the host, then `restic-homelab restore` the media folder.
2. Start Immich on an empty database and pick "Restore from backup" on the
   welcome screen. It checks the folders, then restores a dump from
   `backups/` [18].

NVMe plus Hetzner is two copies, one offsite. iCloud is the third.

## 6. Sign-in

**Immich's own OAuth, pointed at Pocket ID.** Immich's mobile app has OAuth
built in, so no oauth2-proxy gate.

### Pocket ID client

Shane makes it in the UI, following `docs/pve/auth.md`:

- Client ID `immich`, with PKCE and Skip Consent on. Immich sends PKCE when
  the provider supports it [29].
- Callbacks [27][28]:
  - `https://photos.shaneplunkett.com/auth/login`
  - `https://photos.shaneplunkett.com/user-settings`
  - `app.immich:///oauth-callback`, for the iPhone app
- Limit it to Shane, or to an `immich_users` group, on the client's Access
  tab [28].
- Secret in Bitwarden as `immich-oidc-client-secret`, then agenix.

### Immich side, in `settings.oauth`

- `enabled`, `issuerUrl = "https://auth.shaneplunkett.com"`,
  `clientId = "immich"`, and `clientSecret._secret` pointing at the agenix
  file [6][15].
- `autoLaunch = true`, so the login page goes straight to Pocket ID [27].
- `autoRegister = false`. Shane's account already exists, and nobody else
  should get one by accident.
- Keep `passwordLogin` on as a break-glass. `/auth/login?autoLaunch=0`
  reaches the password form [27].

### First sign-in

1. Make the admin account on the web with Shane's Pocket ID email and a
   password, and save the password in Bitwarden.
2. Sign out and sign in with the passkey. Immich links the OAuth login to
   the existing account by email [30].
3. Then set `IMMICH_ALLOW_SETUP=false`, which turns off the admin sign-up
   endpoint [35]. It also turns off the restore endpoint, so flip it back
   for a restore.

## 7. Away from home

**Tailscale,** like everything else. One URL, `https://photos.shaneplunkett.com`.

- Immich's docs list a VPN or Tailscale as the safe options, and warn that
  Immich exposed to the internet is a risk [31].
- Tailscale's VPN On Demand can bring the tunnel up when the phone leaves
  home Wi-Fi [32], so background uploads have a way in.
- Not the Cloudflare tunnel. The Free plan caps uploads at 100 MB [33], and
  phone videos pass that. It would also put Immich on the public internet.

### Ingress

- The ingress already allows any body size and passes websockets. NixOS's
  recommended proxy settings send the forwarding headers Immich asks for
  [25][26].
- It still needs Immich's upload settings, added to the `photos` route
  through the ingress's `serverConfig`: `proxy_request_buffering off`,
  `client_body_buffer_size 1024k`, and 600-second `proxy_read_timeout`,
  `proxy_send_timeout` and `send_timeout` [25]. NixOS's recommended proxy
  settings set timeouts to 60 seconds [26], which is too short for a big
  video.
- Immich listens on localhost by default in the module [6]. Set `host = ""`
  and open the port, and set `IMMICH_TRUSTED_PROXIES` to the ingress's LAN
  address so logs show real client addresses [35].

## 8. Monitoring

- `homelab.monitoring.units`: `immich-server`,
  `immich-machine-learning`, `postgresql` and `redis-immich`.
- `IMMICH_TELEMETRY_INCLUDE=all` turns on Prometheus metrics, on 8081 for
  the API and 8082 for background jobs [34][35]. Scrape both with a job like
  `modules/services/blocky/monitoring.nix`. Pick alert rules once the metric
  names are visible. UNCONFIRMED which ones are worth alerting on.
- The journal already goes to Loki. `IMMICH_LOG_FORMAT=json` makes it
  easier to query [35].
- The base disk alert covers the container's disk, which is also where the
  photos are. It doubles as the "library is filling up" alert.
- Backup freshness alerts come free with the backup module.

## Rollout plan

**Shane** marks steps that need her hands.

### 1. Infra PR

1. Add a `datastore` variable to `terraform/modules/nixos-lxc`, defaulting
   to `local-lvm`.
2. `terraform/cube-photos.tf` on nvme-thin, plus a Storage Box subaccount
   in `terraform/hetzner.tf`.
3. The host file, hive node, host key and `backup-photos` secret, per the
   README's "Adding a host".

### 2. Service PR

4. **Shane:** make the Pocket ID client and put the secret in Bitwarden.
5. `modules/services/immich`: the module, settings with OAuth, route,
   ingress settings, backup paths, units and scrape job.
6. **Shane:** make the admin account, then sign in with her passkey on the
   web and in the iPhone app. Done when the passkey gets her in on both.

### 3. Import

7. **Shane:** back up one Live Photo and one edited photo, and check how
   they look in Immich.
8. **Shane:** the full app backup, at home, plugged in.
9. The Takeout through immich-go, dry run first.
10. **Shane:** review duplicates once the ML jobs finish.
11. Check the next night's restic snapshot has the media folder and a fresh
    dump in `backups/`.

## Later

- **Hardware transcoding** on the UHD 630 through VAAPI, if real-time
  transcoding comes out of preview and matters.
- **Share links for people off the tailnet.** immich-public-proxy serves
  shared links without exposing Immich [37], and nixpkgs has a module for
  it. It could sit behind the Cloudflare tunnel.
- **An Apple data export on Unraid** as a frozen archive, if iCloud goes.

## If family joins

- Make them in Pocket ID, then turn on `autoRegister`, or add them by hand.
- Decide on storage quotas then, since the library lives on cube's NVMe.
- Share links for people off the tailnet are under "Later".

## Sources

1. Immich v3.3.1 release: https://github.com/immich-app/immich/releases/tag/v3.3.1
2. Immich stable release announcement: https://github.com/immich-app/immich/discussions/22546
3. Immich v3.0.0 release notes: https://github.com/immich-app/immich/releases/tag/v3.0.0
4. Immich v3.3.0 release notes: https://github.com/immich-app/immich/releases/tag/v3.3.0
5. Requirements: https://docs.immich.app/install/requirements
6. nixpkgs `services.immich` module: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/web-apps/immich.nix
7. nixpkgs `immich` package history: https://github.com/NixOS/nixpkgs/commits/nixos-unstable/pkgs/by-name/im/immich/package.nix
8. nixpkgs `immich-machine-learning` package: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/im/immich-machine-learning/package.nix
9. Immich ML `pyproject.toml`, backend extras: https://github.com/immich-app/immich/blob/v3.3.1/machine-learning/pyproject.toml
10. Postgres standalone, updating VectorChord: https://docs.immich.app/administration/postgres-standalone
11. Upstream `docker-compose.yml`: https://github.com/immich-app/immich/blob/v3.3.1/docker/docker-compose.yml
12. Hardware transcoding: https://docs.immich.app/features/hardware-transcoding
13. ML hardware acceleration: https://docs.immich.app/features/ml-hardware-acceleration
14. nixpkgs `intel-media-sdk`, `knownVulnerabilities`: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/in/intel-media-sdk/package.nix
15. Config file: https://docs.immich.app/install/config-file
16. Custom file locations: https://docs.immich.app/guides/custom-locations
17. System integrity, folder checks: https://docs.immich.app/administration/system-integrity
18. Backup and restore: https://docs.immich.app/administration/backup-and-restore
19. Mobile backup: https://docs.immich.app/features/mobile-backup
20. FAQ, iOS background backup: https://docs.immich.app/FAQ
21. Mobile upload service, iCloud and Live Photo handling: https://github.com/immich-app/immich/blob/v3.3.1/mobile/lib/services/foreground_upload.service.dart
22. Apple, get a copy of your data: https://support.apple.com/en-us/102208
23. immich-go, `upload from-icloud`: https://github.com/simulot/immich-go/blob/main/docs/commands/upload.md
24. icloudpd: https://github.com/icloud-photos-downloader/icloud_photos_downloader
25. Reverse proxy: https://docs.immich.app/administration/reverse-proxy
26. nixpkgs nginx module, recommended proxy settings: https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/services/web-servers/nginx/default.nix
27. OAuth: https://docs.immich.app/administration/oauth
28. Pocket ID, Immich client example: https://pocket-id.org/docs/client-examples/immich
29. Immich OAuth repository, PKCE: https://github.com/immich-app/immich/blob/v3.3.1/server/src/repositories/oauth.repository.ts
30. Immich auth service, linking by email: https://github.com/immich-app/immich/blob/v3.3.1/server/src/services/auth.service.ts
31. Remote access: https://docs.immich.app/guides/remote-access
32. Tailscale, VPN On Demand: https://tailscale.com/kb/1291/ios-vpn-on-demand
33. Cloudflare upload limits: https://developers.cloudflare.com/cache/concepts/default-cache-behavior/#upload-limits
34. Monitoring: https://docs.immich.app/features/monitoring
35. Environment variables: https://docs.immich.app/install/environment-variables
36. External libraries: https://docs.immich.app/features/libraries
37. immich-public-proxy: https://github.com/alangrainger/immich-public-proxy
38. Remote machine learning: https://docs.immich.app/guides/remote-machine-learning
39. Immich v3.2.0 release notes: https://github.com/immich-app/immich/releases/tag/v3.2.0
40. Facial recognition: https://docs.immich.app/features/facial-recognition
41. Searching: https://docs.immich.app/features/searching
42. Partner sharing: https://docs.immich.app/features/partner-sharing
43. Duplicates utility: https://docs.immich.app/features/duplicates-utility
44. Supported formats: https://docs.immich.app/features/supported-formats
45. immich-go, `upload from-google-photos`: https://github.com/simulot/immich-go/blob/main/docs/commands/upload.md
46. immich-go, technical notes (JSON metadata, duplicate detection): https://github.com/simulot/immich-go/blob/main/docs/technical.md
47. Google Photos, backup quality: https://support.google.com/photos/answer/6220791
