# Australian free-to-air streams into Plex DVR

- **Question:** Does Plex let you record from streaming channels, or is there a hacky way to set it up? Asked as a stopgap while the building's TV aerial is down.
- **Researched:** 2026-10-25, normal

## Sub-questions

1. Are free M3U playlists and XMLTV guides for Melbourne free-to-air TV still live and maintained? answered
2. Is Threadfin, or another HDHomeRun emulator, still maintained? answered
3. Does Plex DVR still accept an emulated HDHomeRun tuner fed from internet streams, and record from it? answered, with gaps
4. Is there a NixOS package, module or container for Threadfin or its alternatives? answered

## Claims

Each claim gives its source, the source's date, and a verdict.

### Playlists and guides

- i.mjh.nz/au/Melbourne/ is live, with epg.xml(.gz), kodi-tv.m3u8 and tv.json regenerated on the day. [Source](https://i.mjh.nz/au/Melbourne/), 2026-10-25, confirmed.
- The Melbourne playlist is `kodi-tv.m3u8`, with 171 entries including Seven, 7two, 7mate, 7flix, 9, 9Gem, 9Go, 9Life, 9Rush, ABC TV, 10, 10 Bold, 10 Peach and SBS. `playlist.m3u8` 404s. [Source](https://i.mjh.nz/au/Melbourne/kodi-tv.m3u8), 2026-10-25, confirmed.
- `tvh-tv.m3u8` uses `pipe://ffmpeg` entries for Tvheadend, so Plex-facing tools need the plain-URL kodi variant. Whether its `#EXTVLCOPT` headers are honoured is untested. [Source](https://i.mjh.nz/au/Melbourne/tvh-tv.m3u8), 2026-10-25, confirmed (Plex behaviour unverified).
- epg.xml.gz redirects to GitHub raw and carries Melbourne channel IDs (mjh-abc-vic, mjh-channel-9-vic, mjh-10-vic, mjh-seven-mel) with the day's programmes. [Source](https://i.mjh.nz/au/Melbourne/epg.xml.gz), 2026-10-25, confirmed.
- matthuisman/i.mjh.nz is the mirror repo: not archived, pushed on the day, 39 open issues, no licence. [Source](https://github.com/matthuisman/i.mjh.nz), 2026-10-25, confirmed.
- Issues are filed and closed through 2026 (#314 10 DAI key 404, #316 VPN, #317 Darwin EPG). [Source](https://github.com/matthuisman/i.mjh.nz/issues), 2026-10-22, confirmed.
- ABC, 9, SBS, Seven and 10 Melbourne streams each returned 200 from an AU IP, as single probes rather than soak tests. Source: i.mjh.nz `.r/` and c.mjh.nz endpoints, 2026-10-25, confirmed (AU egress only).
- Seven and its multichannels only work from an Australian IP. [Source](https://www.matthuisman.nz/2017/07/australia-iptv-epg-files.html), 2017-07-31, confirmed as the owner's statement, not retested outside AU.
- Channel 9 needs a 9Now token. [Source](https://github.com/matthuisman/i.mjh.nz/issues/116), 2024-08-02, superseded: Channel 9 Melbourne returned 200 with no token on 2026-10-25.
- The 2026 breakages (#295 Channel 10, #301-303 Channel 9 at 480x270, #308 SBS Canberra 403, #314 10 DAI key) are all closed, and none is open for Melbourne. [Source](https://github.com/matthuisman/i.mjh.nz/issues), 2026-06 to 2026-10, confirmed.
- epgshare01 AU1 is a maintained alternative guide with Melbourne IDs, updated on the day, about 31 MB decoded, with no stream URLs. [Source](https://epgshare01.online/epgshare01/epg_ripper_AU1.xml.gz), 2026-10-25, confirmed.
- iptv-org's AU list lacks Seven and SBS and points ABC at c.mjh.nz. [Source](https://iptv-org.github.io/iptv/countries/au.m3u), 2026-10-25, confirmed.
- Free-TV/IPTV's Australia list links to i.mjh.nz, so it isn't independent. [Source](https://github.com/Free-TV/IPTV/blob/master/lists/australia.md), undated, confirmed.
- The networks publish no first-party free M3U. No source, unconfirmed.

### HDHomeRun emulators

- Threadfin's latest release is 1.2.37. [Source](https://github.com/Threadfin/Threadfin/releases/tag/1.2.37), 2025-09-11, confirmed.
- Threadfin's last commit on main is 2025-09-29, and its last merged PR is 2025-09-25. [Source](https://github.com/Threadfin/Threadfin/commits/main), 2025-09-29, confirmed.
- Threadfin has unreleased branches 1.2.39 and 1.2.40. [Source](https://github.com/Threadfin/Threadfin/branches), 2025-10-03, confirmed.
- Six Threadfin PRs have been open since 2026-06-18 with no maintainer response, and issues are disabled. [Source](https://github.com/Threadfin/Threadfin/pulls), 2026-06-18, confirmed.
- Threadfin is "actively maintained". [Source](https://mariushosting.com/how-to-install-threadfin-on-your-synology-nas), undated, contradicted by the commit record above.
- Threadfin's README lists Plex Pass as required for Plex DVR. [Source](https://github.com/Threadfin/Threadfin/blob/main/README.md), undated, confirmed.
- xTeVe's last release is 2.2.0.200, with no maintainer commits since. [Source](https://github.com/xteve-project/xTeVe/releases/tag/2.2.0.200), 2021-03-29, confirmed.
- xteve-reborn is a fork created 2026-09-11, latest v3.0.5. [Source](https://github.com/theantipopau/xteve-reborn/releases/tag/v3.0.5), 2026-10-10, confirmed.
- Dispatcharr's latest is v0.33.0, and its README documents HDHomeRun emulation for Plex. [Source](https://github.com/Dispatcharr/Dispatcharr/releases/tag/v0.33.0), 2026-10-24, confirmed.
- Tunarr's latest is v2026.10.3, with a spoofed HDHomeRun tuner. Plain M3U passthrough is unchecked. [Source](https://github.com/chrisbenincasa/tunarr/releases/tag/v2026.10.3), 2026-10-16, confirmed (M3U passthrough unconfirmed).
- hdhriptv turns an M3U into an HDHomeRun tuner, latest v1.1.1. [Source](https://github.com/arodd/hdhriptv/releases/tag/v1.1.1), 2026-08-21, confirmed.
- telly is archived. [Source](https://github.com/tellytv/telly), 2018-08-11, confirmed.
- m3u4u, IPTVBoss and m3u-editor show no HDHomeRun emulation. [Source](https://m3u4u.com/), undated, unconfirmed (absence in their pages).

### Packaging

- nixpkgs has no threadfin, tunarr or dispatcharr package on master or 26.05. [Source](https://api.github.com/repos/NixOS/nixpkgs/contents/pkgs/by-name/th/threadfin), 2026-10-25, confirmed.
- nixpkgs packages xteve 2.2.0.200, with no module. [Source](https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/xt/xteve/package.nix), undated, confirmed.
- Open PR #548530 adds a dispatcharr package and a `services.dispatcharr` module at 0.28.2. It has a merge conflict and was last updated 2026-09-18. [Source](https://github.com/NixOS/nixpkgs/pull/548530), 2026-09-18, confirmed; its version is superseded by upstream v0.33.0 (2026-10-24).
- Dispatcharr's image `ghcr.io/dispatcharr/dispatcharr:latest` is multi-arch (amd64, arm64), built 2026-10-24 at 0.33.0. [Source](https://github.com/Dispatcharr/Dispatcharr), 2026-10-24, confirmed.
- Threadfin's image `fyb3roptik/threadfin:latest` was last updated 2025-10-20. [Source](https://hub.docker.com/v2/repositories/fyb3roptik/threadfin/tags), 2025-10-20, confirmed.
- xTeVe's image `alturismo/xteve` was last updated 2021-08-03, amd64 only. [Source](https://hub.docker.com/v2/repositories/alturismo/xteve), 2021-08-03, confirmed.
- Tunarr's image `chrisbenincasa/tunarr` has amd64 and arm64 tags at 2026.10.3. [Source](https://hub.docker.com/v2/repositories/chrisbenincasa/tunarr/tags), 2026-10-16, confirmed.

### Plex

- Plex's supported-tuner list is hardware only and never mentions IPTV, M3U or emulators. [Source](https://support.plex.tv/articles/225877427-supported-dvr-tuners-and-antennas), 2025-02-03, confirmed.
- Plex allows unofficial tuners at your own risk, with no support. [Source](https://support.plex.tv/articles/community-supported-tuners/), 2020-10-31, confirmed.
- The DVR wizard accepts a manually entered network tuner address. [Source](https://support.plex.tv/articles/225877347-live-tv-dvr/), 2024-10-24, confirmed.
- An XMLTV file can replace Plex's guide during DVR setup. [Source](https://support.plex.tv/articles/using-an-xmltv-guide), 2020-04-09, confirmed.
- Recording needs Plex Pass. [Source](https://support.plex.tv/articles/226463767-frequently-asked-questions-dvr-live-tv), 2026-09-30, confirmed.
- The FAQ says watching OTA live is free without Plex Pass, while [plex.tv/tv](https://www.plex.tv/tv) says Live TV and DVR need it. Undated, unconfirmed: the two pages disagree.
- Multiple tuners on one DVR should be the same type. [Source](https://support.plex.tv/articles/226463767-frequently-asked-questions-dvr-live-tv), 2026-09-30, confirmed.
- Plex's free Live TV (FAST) channels cannot be recorded. [Source](https://support.plex.tv/articles/faq-live-tv-on-plex), 2025-09-05, confirmed.
- Lifetime Plex Pass rose from $249.99 to $749.99 on 2026-07-01. [Source](https://www.plex.tv/blog/new-lifetime-plex-pass-pricing), 2026-07-01, confirmed.
- Remote streaming of personal media needs Plex Pass or Remote Watch Pass, extended to more TV platforms on 2026-04-29. [Source](https://www.plex.tv/blog/important-2025-plex-updates), 2026-04-29, confirmed.
- A Tunarr HDHomeRun emulator with XMLTV works on PMS 1.43.5, but the local DVR vanishes from the apps while Plex's online Live TV source is enabled. [Source](https://forums.plex.tv/t/bug-local-live-tv-dvr-disappears-when-plexs-online-live-tv-source-is-enabled/944884), 2026-10-21, unconfirmed (one user, no staff reply).
- PMS 1.43.0 broke live TV transcoding, Tunarr and ErsatzTV included, and test build 1.43.2.10538 fixed it. [Source](https://forums.plex.tv/t/transcoding-live-tv-fails-on-1-43/936640), 2026-02-23 to 2026-04-11, unconfirmed for emulators; staff engagement confirmed.
- Dispatcharr IPTV failed on a Mac PMS 1.43.0 and worked on Windows. An mpeg2video/mp2 ffmpeg profile was the workaround. [Source](https://forums.plex.tv/t/live-tv-error-s1001-network-on-macos-tuner-dispatcharr-setup/936940), 2026-03-09, unconfirmed.
- The Apple TV and iPhone app 2026.19.1 fails every second live tune with "Can't Reach Server" on a real HDHomeRun. [Source](https://forums.plex.tv/t/plex-2026-19-1-apple-tv-and-iphone-every-second-live-tv-tune-fails-with-can-t-reach-server/944386), 2026-10-11, unconfirmed.
- Plex rolled back its big-screen app redesign and said Live TV sources would become reorderable. [Source](https://www.xda-developers.com/after-months-backlash-plex-rolling-back-controversial-big-screen-app-redesign), 2026-08-18, unconfirmed (secondary).
- Plex added a native M3U field under Live TV & DVR. [Source](https://www.reddit.com/r/PleX/comments/1cmtgcm/native_plex_iptv_tuner), 2024, unconfirmed (Reddit blocked).

## Gaps

- No Plex-owned page blesses or bans HTTP HDHomeRun emulators, so the emulator path rests on user reports. Proving it means a test on this server.
- Whether a second, IPTV-type tuner can sit beside the real HDHomeRun FLEX QUATRO on one DVR is unclear, given the same-type rule.
- Stream stability over hours, and Plex's handling of the kodi playlist's `#EXTVLCOPT` headers, are untested.
- Melbourne guide accuracy against the broadcast schedule wasn't checked.
- Whether Remote Watch Pass covers Live TV for remote users wasn't settled.
- The broadcasters' terms for retransmitting their streams weren't checked, and the mjh.nz content carries no licence.
