# Nix CI on GitHub-hosted runners

- **Question:** Check Atelier from StepBro, the Determinate Nix things and nix-eval-jobs, basically all the big girl Nix stuff for people using runners on GitHub, now that caboodle is moving back to GitHub with hosted runners, a cache at home and no local builder. Plus a minimal git mirror now Soft Serve is archived.
- **Researched:** 2026-10-31, deep (Tavily pro run verified by one agent, then four normal-mode passes on its gaps)
- **Context:** [Moving back to GitHub](../prd/forge-and-builder.md) and the [28 October CI patterns research](2026-10-28-nix-ci-patterns.md), which this extends rather than repeats. No evaluations, builds or infrastructure changes ran during this research.

## Sub-questions

1. Atelier and `inc`: answered.
2. Determinate actions, Magic Nix Cache, FlakeHub Cache, Determinate Nix: answered; whether Determinate Nix helps a 16 GB runner is a gap.
3. Evaluation and matrix tooling on a 4-vCPU 16 GB runner: answered; no published per-host memory figures.
4. Attic versus niks3 for a cache at home: answered.
5. Caching the runner's own store between jobs: answered.
6. Hosted Nix CI services: answered.
7. Minimal git mirror now Soft Serve is archived: answered.
8. GitHub facts: answered; the 500 MB artifact storage figure for public repos is a gap.

## What this suggests for caboodle

Atelier is a reusable workflow from the Colmena maintainer that already does the per-derivation matrix on hosted runners and pushes to Attic, so the derivation diff can sit beside it rather than reinventing the fan-out. Attic is the cache server that stores on local disk with SQLite and ships as `services.atticd` in nixpkgs 25.11; niks3 is S3-only with Postgres, so at home it would need an S3 server beside it. Pushes go over Tailscale, which sidesteps Attic's one-request-per-NAR upload and Cloudflare's 100 MB body cap. The mirror is plain `git clone --mirror` on a timer, listing repos through the GitHub App. garnix is gone, Hercules still needs a builder at home, and nixbuild.net only sells build time.

## Claims

### Atelier and inc

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| Atelier is MIT and active, pushed 2026-10-31; it fans out one native build per derivation on GitHub-hosted runners, with `atelier.toml` selecting attributes | [readme](https://github.com/stepbrobd/atelier) | undated, repo pushed 2026-10-31 | confirmed |
| Consumers call `stepbrobd/atelier/.github/workflows/discover.yaml@master`; the readme's `ci.yaml` is a caller example, not Atelier's own CI | [readme](https://github.com/stepbrobd/atelier) | undated | confirmed; the deep report misread it as Atelier's CI |
| Push backends are Attic (`ATTIC_SERVER`, `ATTIC_CACHE`, `ATTIC_TOKEN`), Cachix and niks3 | [readme](https://github.com/stepbrobd/atelier) | undated | confirmed |
| niks3 authenticates by GitHub Actions OIDC by default with only `NIKS3_SERVER` set; `NIKS3_TOKEN` is the static alternative | [readme](https://github.com/stepbrobd/atelier) | undated | confirmed |
| The readme says to "consider adding" the niks3 cache as a substituter; it is not a hard requirement | [readme](https://github.com/stepbrobd/atelier) | undated | contradicted the deep report's "requires" |
| Matrix jobs are independent; duplicate builds are expected and outputs already in a substituter are skipped | [readme](https://github.com/stepbrobd/atelier) | undated | confirmed |
| Atelier has no GitHub releases, so pin a commit SHA | [releases API](https://api.github.com/repos/stepbrobd/atelier/releases/latest) | 2026-10-31 | confirmed |
| `inc` is MIT, has an `atelier.toml` with substituter `cache.ysun.co`, and deploys on `master` after CI via `tailscale/github-action@v4` on `workflow_run` | [inc](https://github.com/stepbrobd/inc) | 2026-10-31 | confirmed |
| Atelier's readme describes itself as inspired by garnix "(RIP)" | [readme](https://github.com/stepbrobd/atelier) | undated | confirmed, and garnix's shutdown is confirmed below |

### Determinate Systems

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| `determinate-nix-action` pins Determinate Nix versions; v3.24.1 released 2026-10-26 | [repo](https://github.com/DeterminateSystems/determinate-nix-action) | 2026-10-26 | confirmed |
| `nix-installer-action` installs the latest Nix; v23 released 2026-09-09 | [repo](https://github.com/DeterminateSystems/nix-installer-action) | 2026-09-09 | confirmed |
| `flake-iter` builds every derivation and detects the current system when none is given; repo last pushed 2026-03-11, no releases | [readme](https://github.com/DeterminateSystems/flake-iter) | 2026-03-11 | confirmed, aging |
| `DeterminateSystems/ci`, `update-flake-lock` and `flake-checker-action` are in Determinate's GitHub Actions guide; `ci`'s multi-arch and FlakeHub-upload behaviour was not verified | [guide](https://docs.determinate.systems/guides/github-actions) | undated | unconfirmed for behaviour |
| Magic Nix Cache's free tier shutting down on 2025-02-01 is superseded: the free service returned on 2025-06-13, the readme says "totally free", v15 released 2026-09-09, repo pushed 2026-10-27 | [revival post](https://discourse.nixos.org/t/65620), [readme](https://github.com/DeterminateSystems/magic-nix-cache-action) | 2025-06-13; 2026-09-09 | superseded |
| FlakeHub pricing: Free $0 for public flakes; Individual $7/mo with private flakes and FlakeHub Cache, 15 GB egress a month then $0.09/GB, cache storage free "for a limited time"; Team $20/user/mo | [pricing](https://flakehub.com/pricing) | undated, footer 2026 | confirmed |
| The 2024 launch priced FlakeHub Cache at $20/member/month with storage and bandwidth included for an introductory period | [launch post](https://determinate.systems/blog/flakehub-cache-and-private-flakes) | 2024-10-23 | superseded by the pricing page above |
| FlakeHub Cache authenticates by JWT via GitHub Actions OIDC; it is a hosted cache | [launch post](https://determinate.systems/blog/flakehub-cache-and-private-flakes) | 2024-10-23 | confirmed |
| Determinate Nix evaluated single-threaded in 23.70 s and multi-threaded in 5.77 s on a 12-core Ryzen 5900X | [blog](https://determinate.systems/blog/parallel-nix-eval) | 2024-06-27 | confirmed as a benchmark, not a 4-vCPU runner figure |
| Lazy trees are on by default and cut disk use on large repos | not reached | undated | unconfirmed |
| Determinate Nix is LGPL-2.1; latest v3.24.1 published 2026-10-25 | [nix-src](https://github.com/DeterminateSystems/nix-src) | 2026-10-25 | confirmed |
| A third-party CI log shows a Determinate action note that individuals must register at FlakeHub from 2026-06-02 | [vic/vix run](https://github.com/vic/vix/actions/runs/24121120504) | 2026-04-08 | unconfirmed at a Determinate page |

### Evaluation and matrix tooling

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| nix-eval-jobs defaults to 4 GiB `max-memory-size` per worker; workers × max-memory-size is one combined budget; rule of thumb is workers = cores and memory ÷ workers | [readme](https://github.com/nix-community/nix-eval-jobs) (now NixOS/nix-eval-jobs, pushed 2026-09-17) | undated | confirmed |
| nix-eval-jobs has no GitHub releases | [releases API](https://api.github.com/repos/nix-community/nix-eval-jobs/releases/latest) | 2026-10-31 | confirmed; the deep report's "recent release notes" is unconfirmed |
| nix-fast-build: `--eval-workers` defaults to the CPU count, `--eval-max-memory-size` to 4096 MiB; `--copy-to` and `--skip-cached` exist; latest release 2.0.4 | [options.py](https://github.com/Mic92/nix-fast-build/blob/main/nix_fast_build/options.py), [releases](https://github.com/Mic92/nix-fast-build/releases) | 2026-09-28 | confirmed |
| `nix-community/nix-github-actions` converts flake attribute sets to matrices; MIT, no releases, pushed 2026-06-18 | [repo](https://github.com/nix-community/nix-github-actions) | 2026-06-18 | unconfirmed, readme not read |
| Hestia uses the GitHub Actions cache: 10 GB per repo, LRU and 7-day idle eviction, CI only | [readme](https://github.com/Mic92/hestia) | undated | confirmed from Hestia's readme |
| No published memory figures for evaluating one NixOS host versus many were found | none | n/a | gap |

### Attic

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| Attic has no GitHub releases or tags | [tags API](https://api.github.com/repos/zhaofengli/attic/tags) | 2026-10-31 | confirmed |
| Last commit on `main` is 2026-07-06, after about 45 commits in June 2026 following a quiet stretch; 132 open issues | [commits](https://github.com/zhaofengli/attic/commits/main) | 2026-07-06 | confirmed |
| The maintainer said in May and June 2026 that he can maintain more actively, and in July that he is migrating to the nix-daemon worker protocol | [PR 317](https://github.com/zhaofengli/attic/pull/317), [issue 354](https://github.com/zhaofengli/attic/issues/354) | 2026-05-07; 2026-06-10; 2026-07-22 | confirmed |
| The Celler fork said upstream had stalled for seven months | [Discourse](https://discourse.nixos.org/t/celler-an-attic-fork/77265) | 2026-04-27 | superseded by the June and July 2026 commits |
| `services.atticd` exists in nixos-25.11, nixos-26.05 and master, with `enable`, `package`, `environmentFile` (required), `user`, `group`, `settings`, `mode`; defaults are local storage at `/var/lib/atticd/storage`, SQLite at `/var/lib/atticd/server.db`, chunking threshold 65536 | [module](https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/networking/atticd.nix) | 2025-06-24 | confirmed |
| nixos-25.11 packages attic-server from a 2025-09-24 snapshot; master has 2026-07-06 | [package](https://github.com/NixOS/nixpkgs/blob/nixos-25.11/pkgs/by-name/at/attic-server/package.nix) | 2025-09-24; 2026-07-06 | confirmed |
| The module's assertion names `ATTIC_SERVER_TOKEN_RS256_SECRET` while its description says `_BASE64` | [module](https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/networking/atticd.nix) | 2025-06-24 | unconfirmed, module not evaluated |
| Storage backends are `local` and `s3`; the readme only mentions S3 | [config.rs](https://github.com/zhaofengli/attic/blob/main/server/src/config.rs) | 2026-07-06 | confirmed |
| Database is SQLite or PostgreSQL through sea-orm | [Cargo.toml](https://github.com/zhaofengli/attic/blob/main/server/Cargo.toml) | 2026-07-06 | confirmed |
| A single-chunk NAR on S3 is served by a 307 to a presigned URL; on local storage the server streams it; any multi-chunk NAR is reassembled and streamed by the server | [binary_cache.rs](https://github.com/zhaofengli/attic/blob/main/server/src/api/binary_cache.rs) | 2026-07-06 | confirmed |
| `upstream-cache-key-names` is per-cache state set with `attic cache create/configure --upstream-cache-key-name`, default `cache.nixos.org-1`; the server treats it as a hint and the client drops paths signed by a listed key from the push plan; `--ignore-upstream-cache-filter` bypasses it | [cache.rs](https://github.com/zhaofengli/attic/blob/main/client/src/command/cache.rs), [push.rs](https://github.com/zhaofengli/attic/blob/main/client/src/push.rs) | 2026-07-06 | confirmed; not an `atticd.toml` key |
| GC runs every 43200 s by default, zero disables it, `atticd --mode garbage-collector-once` runs it by hand; `default-retention-period` defaults to zero, per-cache retention via `attic cache configure --retention-period`; GC deletes objects created before the cutoff and not accessed since, then orphan NARs and chunks | [config.rs](https://github.com/zhaofengli/attic/blob/main/server/src/config.rs), [gc.rs](https://github.com/zhaofengli/attic/blob/main/server/src/gc.rs) | 2026-07-06 | confirmed |
| `atticadm make-token` takes `--sub`, `--validity` and wildcard scopes `--pull`, `--push`, `--delete`, `--create-cache`, `--configure-cache`, `--configure-cache-retention`, `--destroy-cache`; tokens are JWTs signed RS256 or HS256, and the nixpkgs module requires RS256 | [make_token.rs](https://github.com/zhaofengli/attic/blob/main/server/src/adm/command/make_token.rs) | 2026-07-06 | confirmed |
| The client sends each NAR as one streamed PUT to `/_api/v1/upload-path`; there is no chunked upload; issue 287 to add it is open, last active 2026-05-02; the maintainer noted Cloudflare's free-plan 100 MB body limit | [api/mod.rs](https://github.com/zhaofengli/attic/blob/main/client/src/api/mod.rs), [issue 287](https://github.com/zhaofengli/attic/issues/287), [issue 281](https://github.com/zhaofengli/attic/issues/281) | 2026-07-06; 2026-05-02; 2025-09-17 | confirmed |
| Cloudflare request body limits: Free and Pro 100 MB, Business 200 MB, Enterprise up to 5 GB, 413 above | [limits](https://developers.cloudflare.com/workers/platform/limits) | undated | confirmed from the Workers limits page, stated at plan level |
| `ryanccn/attic-action` v0.5.2 published 2026-09-21; inputs `endpoint`, `cache`, `token`; installs attic from nixpkgs-unstable | [repo](https://github.com/ryanccn/attic-action) | 2026-09-21 | confirmed |

### niks3

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| The repo is `Mic92/niks3`; `numtide/niks3` does not exist. numtide's `cache.numtide.com` is a listed deployment, with `cache.clan.lol` and `cache.dos.cit.tum.de` | [repo](https://github.com/Mic92/niks3) | 2026-10-31 | confirmed |
| Latest release v1.15.0 on 2026-10-12; main pushed 2026-10-28; created 2024-10-02; 317 stars; 2 open issues; 1.0 announced 2025-12-13 and 1.5 on 2026-05-10 | [releases](https://api.github.com/repos/Mic92/niks3/releases/latest), [1.0](https://discourse.nixos.org/t/niks3-1-0-a-s3-backed-nix-binary-cache-with-gc/73216), [1.5](https://discourse.nixos.org/t/niks3-1-5-release/77539) | 2026-10-12 | confirmed |
| nixpkgs master has niks3 1.15.0, nixos-26.05 has 1.6.0, nixos-25.11 has none; the `services.niks3` module lives only in the niks3 flake | [nixpkgs](https://github.com/NixOS/nixpkgs/commits/master/pkgs/by-name/ni/niks3), [module](https://github.com/Mic92/niks3/blob/main/nix/nixosModules/niks3.nix) | 2026-10-12; 2026-10-28 | confirmed |
| Storage is S3 only (all server flags are `-s3-*`), so MinIO, Garage or SeaweedFS is needed at home; the database is PostgreSQL only | [main.go](https://github.com/Mic92/niks3/blob/main/server/main.go) | 2026-10-28 | confirmed |
| GC is reference-tracking: closures older than `gc.olderThan` (default 720 h) are removed, orphans reaped, failed uploads cleaned after 6 h, on a daily timer | [module](https://github.com/Mic92/niks3/blob/main/nix/nixosModules/niks3.nix) | 2026-10-28 | confirmed |
| Auth is a bearer token, OIDC (GitHub Actions, GitLab CI, Kubernetes) or mTLS | [main.go](https://github.com/Mic92/niks3/blob/main/server/main.go), [OIDC wiki](https://github.com/Mic92/niks3/wiki/OIDC) | 2026-10-25 | confirmed |
| Clients read NARs straight from S3 by default; `--enable-read-proxy` proxies and `--read-redirect-ttl` answers with a 307 to a presigned URL; clients PUT NARs straight to S3 via presigned URLs in 10 MiB multipart parts, NARs of 10 MiB or less in one PUT | [readme](https://github.com/Mic92/niks3/blob/main/README.md), [multipart.go](https://github.com/Mic92/niks3/blob/main/client/multipart.go) | 2026-10-12; 2026-10-28 | confirmed |
| `Mic92/niks3-action` v1.5.0 published 2026-10-12 uses GitHub OIDC (`id-token: write`), takes `server-url`, reads substituter and keys from `/api/cache-config`, uploads via post-build-hook and drains in a post step; fork PRs configure but do not upload | [action](https://github.com/Mic92/niks3-action), [wiki](https://github.com/Mic92/niks3/wiki/GitHub-Actions) | 2026-10-12 | confirmed |
| `stepbrobd/inc` pushes to niks3 | search | n/a | unconfirmed |

### Caching the runner's store

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| `nixbuild/nix-quick-install-action` v35 released 2026-06-17 | [releases](https://api.github.com/repos/nixbuild/nix-quick-install-action/releases/latest) | 2026-06-17 | confirmed |
| `nix-community/cache-nix-action` v7 released 2026-01-08; v7 caches only `/nix` by default | [releases](https://api.github.com/repos/nix-community/cache-nix-action/releases/latest) | 2026-01-08 | confirmed |
| cache-nix-action needed a migration for the 2025-02-01 cache v2 rollout | [RELEASES.md](https://github.com/nix-community/cache-nix-action/blob/main/RELEASES.md) | undated | contradicted: that file is actions/cache's changelog copied in |
| GitHub Actions cache is 10 GB per repo on Free; 7-day idle eviction is from Hestia's readme, not GitHub's page | [limits](https://docs.github.com/en/actions/reference/limits) | undated, current docs | confirmed for 10 GB; eviction unconfirmed at the primary |
| Whether caching `/nix` in Actions is worthwhile beside a home cache was the deep report's inference | n/a | n/a | unconfirmed reasoning |

### Hosted Nix CI services

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| garnix's hosted service shut down on 2026-07-15 with all data deleted; the code went open source and the team joined Shopify | [shutdown post](https://garnix.io/blog/shutting-down), [Discourse](https://discourse.nixos.org/t/garnix-is-shutting-down-not-oc/77895) | 2026-05-28 | confirmed |
| garnix.io's homepage, docs and pricing still read as a live product | [garnix.io](https://garnix.io) | undated | superseded by the shutdown post; stale pages |
| garnix's last pricing was Free $0 with 1,500 min/mo, Individual $25/mo with 10,000 min; it deployed NixOS hosts | [pricing](https://garnix.io/pricing) | undated | superseded by the shutdown |
| `garnix-io/garnix-ci` is BSD-3, created 2026-05-27, last pushed 2026-06-17, run locally via nixos-compose | [repo](https://github.com/garnix-io/garnix-ci) | 2026-06-17 | confirmed |
| Numtide polled interest in keeping garnix going as self-hosted OSS; no outcome found | [Discourse](https://discourse.nixos.org/t/garnix-is-shutting-down-not-oc/77895) | 2026-05-30 | unconfirmed |
| Hercules CI: Open Source tier free with unlimited agents and public repos; paid €29 per active user per month | [home](https://hercules-ci.com) | undated | unconfirmed; pricing page is client-rendered |
| Hercules' agent runs evaluations and builds on your own infrastructure; caches can be Cachix or S3-type; deployment is via Effects, flagged beta | [docs](https://docs.hercules-ci.com/hercules-ci/getting-started/) | undated | confirmed |
| nixbuild.net: 25 free CPU hours on signup and 25 a month once billing is on, then €0.12 per CPU-hour, called introductory | [pricing](https://docs.nixbuild.net/cloud/pricing) | undated | confirmed |
| nixbuild.net is a remote builder (`--store ssh-ng://eu.nixbuild.net`, `nix build` only); `nixbuild-action` sets it up from Actions; results stay remote unless copied to your own cache; no deploy feature | [remote builds](https://docs.nixbuild.net/cloud/remote-builds), [action](https://github.com/nixbuild/nixbuild-action) | undated; 2026-08-19 | confirmed |
| Cachix public caches are free for open source (5 GB, 20 Deploy agents); private plans are contact-for-pricing | [pricing](https://www.cachix.org/pricing) | undated | confirmed |
| Cachix Deploy is GA and deploys NixOS, nix-darwin and home-manager profiles from the cache | [blog](https://blog.cachix.org/posts/2026-01-28-cachix-deploy-ga-and-cachix-1-10) | 2026-01-28 | confirmed |

### Git mirror

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| Soft Serve was archived 2026-10-26, is sunset with no further security updates, invites a fork and names no successor; last release v0.12.4 on 2026-10-23; nixpkgs has `services.soft-serve` | [readme](https://github.com/charmbracelet/soft-serve/blob/main/README.md), [release](https://github.com/charmbracelet/soft-serve/releases/tag/v0.12.4) | 2026-10-26 | confirmed |
| No git server appears among the charm org's ten most recently pushed repos | [org repos](https://api.github.com/orgs/charmbracelet/repos) | 2026-10-31 | confirmed for the top ten |
| `git clone --mirror` maps all refs with a refspec that `git remote update` overwrites | [git-clone](https://git-scm.com/docs/git-clone) | undated, current manual | confirmed |
| `GET /user/repos` returns private repos with a fine-grained PAT holding Metadata read; `GET /users/{user}/repos` lists public only; a classic PAT needs `repo` | [repos API](https://docs.github.com/en/rest/repos/repos), [scopes](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/scopes-for-oauth-apps) | current docs | confirmed |
| An installation token works for git over HTTPS as `x-access-token:TOKEN@github.com/owner/repo.git`, needs Contents, and expires after an hour; an installation can list its repos | [installation auth](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation), [installations API](https://docs.github.com/en/rest/apps/installations) | current docs | confirmed |
| `gh repo list` defaults to 30 results and needs `--limit`; `--visibility` and `--source` exist | `gh repo list --help` | 2026-10-31 | confirmed |
| gickup lists the token's own repos via `/user/repos` so private ones are included; App mode takes app id, installation id and key; local destination supports `bare`, `mirror`, `structured`, `zip`, `keep`, `lfs`; top-level `cron:` schedules; refresh is `git fetch --all` without prune | [github.go](https://github.com/cooperspencer/gickup/blob/main/github/github.go), [conf.example.yml](https://github.com/cooperspencer/gickup/blob/main/conf.example.yml), [gitcmd.go](https://github.com/cooperspencer/gickup/blob/main/gitcmd/gitcmd.go) | 2026-10-21 | confirmed by code reading, not run |
| gickup v0.10.47 released 2026-09-13, Apache-2.0, pushed 2026-10-21; nixpkgs has 0.10.45 and no NixOS module | [release](https://github.com/cooperspencer/gickup/releases/tag/v0.10.47), [package](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/gi/gickup/package.nix) | 2026-09-13 | confirmed; nixpkgs version superseded |
| cgit v1.3.1 (2026-05-04) is in nixpkgs with `services.cgit` | [cgit](https://git.zx2c4.com/cgit/) | 2026-05-04 | confirmed |
| gitweb ships in git (v2.56.0 tagged 2026-09-28) with `services.gitweb` | [git](https://github.com/git/git) | 2026-09-28 | confirmed |
| klaus 3.0.1 last released 2024-06-17; in nixpkgs, no module | [klaus](https://github.com/jonashaag/klaus) | 2024-06-17 | confirmed, stale |
| stagit 1.3 released 2026-09-14; in nixpkgs, no module | [releases](https://codemadness.org/releases/stagit/) | 2026-09-14 | confirmed |
| icyphox/legit last released v0.2.4 (2024-10-06), pushed 2025-02-15; nixpkgs' `legit` is a different project | [legit](https://github.com/icyphox/legit) | 2024-10-06 | confirmed, stale; "nixpkgs packages legit" contradicted |
| gitolite v3.6.15 (2026-08-08) is in nixpkgs with a module; SSH access control, no web view | [gitolite](https://github.com/sitaramc/gitolite) | 2026-08-08 | confirmed |
| Gitea v28.2.0 (2026-10-18) and Forgejo v17.0.1 (2026-10-26) are current in nixpkgs; Forgejo's pull mirror asks for auth on private repos | [gitea](https://github.com/go-gitea/gitea/releases), [forgejo](https://codeberg.org/forgejo/forgejo/releases) | 2026-10-18; 2026-10-26 | confirmed; full forges |

### GitHub facts

| Claim | Source | Date | Verdict |
| --- | --- | --- | --- |
| `ubuntu-latest` for public repos is 4 vCPU, 16 GB RAM, 14 GB SSD; `macos-latest` and `macos-15` are a 3-core M1 with 7 GB RAM and 14 GB SSD; `macos-15-intel` is 4 cores and 14 GB | [runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners) | undated, current docs | confirmed |
| Standard Linux runners may now run on multi-cloud compute, so allowlists need the published IP ranges; no spec change | [changelog](https://github.blog/changelog/2026-10-28-github-actions-adds-multi-cloud-compute-to-improve-reliability) | 2026-10-28 | confirmed |
| Standard runners in public repos are free with no cap stated | [billing](https://docs.github.com/en/actions/concepts/billing-and-usage) | undated, current docs | confirmed; the deep report's 2,000-minute figure for public repos is contradicted |
| Private repos on Free get $12/month of included compute, no longer a fixed minute count; Linux 2-core is $0.006/min and macOS $0.062/min; rates cut from 2026-01-01 | [billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [changelog](https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions) | current docs; 2025-12-16 | confirmed; the minute unit is superseded |
| Free allows 20 concurrent jobs and 5 concurrent macOS jobs | [limits](https://docs.github.com/en/actions/reference/limits) | undated, current docs | confirmed |
| Artifact retention defaults to 90 days; public repos can set 1 to 90, private 1 to 400; from 2026-10-01 the policy also covers checks, runs and statuses | [settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository) | undated, current docs | confirmed |
| Free artifact storage is 500 MB shared with Packages; the docs measure it for private repos only | [billing](https://docs.github.com/en/actions/concepts/billing-and-usage) | undated | unconfirmed for public repos |
| Environments, environment secrets, deployment protection rules and deployment branch rules are available in public repos on every plan | [environments](https://docs.github.com/en/actions/reference/environments) | undated, current docs | confirmed |
| Rulesets and protected branches are available in public repos on Free; private repos need Pro, Team or Enterprise | [rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets), [protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) | undated, current docs | confirmed |
| Required status checks with "require branches to be up to date" exist, and strict is the default | [rules](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/available-rules-for-rulesets) | undated, current docs | confirmed |
| `pull_request` from a fork gets no secrets except a read-only `GITHUB_TOKEN`; `pull_request_target` runs in the base repo's context with secrets | [events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows) | undated, current docs | confirmed |
| `actions/create-github-app-token` v3.3.0 (2026-10-12) takes `client-id` (preferred over `app-id`), `private-key`, `owner`, `repositories`, `skip-token-revoke`, `permission-*`; installation tokens last one hour; PRs opened with it trigger workflows, unlike `GITHUB_TOKEN` | [action.yml](https://raw.githubusercontent.com/actions/create-github-app-token/v3.3.0/action.yml), [tokens](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-an-installation-access-token-for-a-github-app), [GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token) | 2026-10-12; current docs | confirmed |
| `tailscale/github-action` v4.4.0 (2026-10-29) takes `oauth-client-id`, `oauth-secret`, `tags`, `version`, `audience` (federated identity), `authkey` (deprecated); nodes are ephemeral and log out in the post step; the tag must be in `tagOwners` and the OAuth client needs `auth_keys`; Tailscale recommends workload identity federation over an OAuth client | [action.yml](https://raw.githubusercontent.com/tailscale/github-action/v4.4.0/action.yml), [Tailscale](https://tailscale.com/docs/solutions/connect-github-cicd-workflows-to-private-infrastructure-without-public-exposure) | 2026-10-29; 2026-01-23 | confirmed |
| The deep report's `tailscale/gitops-acl-action` only tests and applies ACLs | [GitOps](https://tailscale.com/kb/1204/gitops-acls) | undated | contradicted as a deploy mechanism |
| A public repo's reusable workflow can be called from any repo; a caller job may use `strategy`, so a matrix is allowed; limits are 10 nesting levels and 50 reusable workflows per file | [reuse](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations) | undated, current docs | confirmed; the deep report's "cannot define their own matrix" is unconfirmed |
| Creating a `workflow_dispatch` event needs Actions write on the target repo; fine-grained PATs and App installation tokens both qualify | [workflows API](https://docs.github.com/en/rest/actions/workflows) | undated, current docs | confirmed |

## Gaps

- No published memory figure for evaluating one NixOS host alone, so the per-host matrix still needs the measurement the 28 October notes proposed.
- Whether Determinate Nix's parallel evaluation helps on a 4-vCPU 16 GB runner is unmeasured; the only benchmark is a 12-core desktop.
- The 500 MB artifact storage figure is stated for private repos; public repos' storage accounting was not found.
- Hercules CI's pricing page is client-rendered and was not reached; its tiers are from the undated home page.
- Whether the attic client compresses NARs before upload, which changes what the 100 MB cap measures, was not checked; moot over Tailscale.
- gickup's private-repo listing rests on code reading, not a live run.
- Whether `GITHUB_TOKEN` can dispatch a workflow in another repo was not checked at a primary source.
