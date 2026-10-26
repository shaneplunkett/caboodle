# Streaming games from the desktop to the Deck at the Deck's size

- **Question:** How to set up Sunshine on the desktop (4K monitor) and Moonlight on the Steam Deck "goodest", for games, at home or remote, given the Deck's screen is 1280x800. Specifically, can Sunshine (v2026.914, `capture = wlr`) on Hyprland 0.56 stream a headless output made per session at the client's size?
- **Researched:** 2026-10-26, normal

## Sub-questions

1. Can Sunshine's `wlr` capture use an output created after it started, and how does `output_name` select it: answered
2. What env vars and ordering do Sunshine's prep-cmds get: answered
3. How to create, size, use and remove a headless output on Hyprland 0.56: answered, untested live
4. Existing setups, gotchas and alternatives: answered, mostly practitioner reports

## Claims

Each claim, then its source, date and verdict.

- On the desktop, Sunshine listed monitors at service start and again at stream start, straight after `Executing [Desktop]`.
  `~/.config/sunshine/sunshine.log` on the desktop (2026-10-26): confirmed (local log).
- Each capture session re-enumerates outputs: `refresh_displays` calls `wl_display_names()`, which opens a new Wayland connection.
  https://github.com/LizardByte/Sunshine/tree/v2026.914.233613 (`src/video.cpp`, `src/platform/linux/wayland.cpp`, `wlgrab.cpp`) (2026-09-15): confirmed (code).
- Prep-cmd `do` commands run and are waited on inside `/launch`; capture starts later from RTSP.
  same tag, `src/nvhttp.cpp`, `src/process.cpp`, `src/rtsp.cpp`, `src/stream.cpp` (2026-09-15): confirmed (code).
- Enumeration logic is unchanged in pre-releases v2026.1017.185028 and v2026.1018.5342.
  https://github.com/LizardByte/Sunshine/releases (2026-10-18): confirmed.
- `output_name` matches the xdg_output name first (PR #5071), in v2026.516 onwards.
  https://github.com/LizardByte/Sunshine/pull/5071 (2026-05-06): confirmed.
- On the streaming path at v2026.914 a numeric `output_name` doesn't select output N; with no name match Sunshine silently uses the first output.
  same tag, `wlgrab.cpp`, `video.cpp` (2026-09-15): contradicts the PR's back-compat claim (code reading, not run).
- Index selection worked on v2025.924, where display names were indices.
  https://github.com/LizardByte/Sunshine/tree/v2025.924.154138 (2025-09-24): superseded by #5071.
- Docs say to use the connector name; the numeric id "can also be used".
  https://github.com/LizardByte/Sunshine/blob/v2026.914.233613/docs/configuration.md (2026-09-15): name confirmed; numeric part contradicted by code.
- Issue #5087 (wlr ignored `output_name` for a Hyprland headless output) closed with the index workaround on an older build.
  https://github.com/LizardByte/Sunshine/issues/5087 (2026-05-09): confirmed as reported; workaround only.
- `output_name` is global, with no per-app setting.
  same tag, `src/config.cpp`, `src/process.cpp` (2026-09-15): confirmed (code).
- Prep-cmds, `cmd` and `detached` get `SUNSHINE_APP_ID`, `SUNSHINE_APP_NAME`, `SUNSHINE_CLIENT_NAME`, `SUNSHINE_CLIENT_WIDTH`, `_HEIGHT`, `_FPS`, `_HDR`, `_GCMAP`, `_HOST_AUDIO`, `_ENABLE_SOPS`, `_AUDIO_CONFIGURATION`, `_AUDIO_SURROUND_PARAMS`.
  same tag, `src/process.cpp`, `src/nvhttp.cpp`, `docs/app_examples.md` (2026-09-15): confirmed.
- A failing `do` aborts the launch and undoes earlier `do`s.
  same tag, `src/process.cpp` (2026-09-15): confirmed.
- `undo` runs on Moonlight's quit (`/cancel`), app exit, a new launch or shutdown, not on disconnect.
  same tag, `src/nvhttp.cpp`, `src/process.cpp`, `src/stream.cpp` (2026-09-15): confirmed (code).
- A tech-insider write-up says undo runs when the stream ends.
  https://tech-insider.org/sunshine-moonlight-streaming-setup-2026 (undated): contradicted by source.
- `auto-detach` (default true) treats a `cmd` that exits 0 within 5 s as still running, so undo waits for quit.
  same tag, `src/process.cpp` (2026-09-15): confirmed.
- Commands go to boost.process as a string; `${SUNSHINE_CLIENT_*}` only expands inside `sh -c`.
  same tag, `src/platform/linux/misc.cpp`, `docs/app_examples.md` (2026-09-15): confirmed.
- `$(VAR)` expands at config parse time, when `SUNSHINE_CLIENT_*` don't exist yet.
  same tag, `src/process.cpp` (2026-09-15): confirmed (code, not run).
- Global prep-cmds run before an app's own.
  same tag, `src/process.cpp` (2026-09-15): confirmed.
- NixOS `services.sunshine.applications` takes `env` and `apps`, writes `apps.json` to the store and points `file_apps` at it.
  nixpkgs `nixos/modules/services/networking/sunshine.nix` (master) (2026-10-26 (fetched)): confirmed on master; pin not checked.
- The NixOS unit sets `PATH` to null, so prep-cmds need absolute paths or `env.PATH`.
  same module (2026-10-26 (fetched)): confirmed (code, not run).
- Web UI app edits silently don't persist when `file_apps` is in the store.
  same Sunshine tag, `src/confighttp.cpp`, `src/file_handler.cpp` (2026-09-15): unconfirmed at runtime.
- Display-config revert is separate from prep-cmd undo.
  same tag, `docs/configuration.md` (2026-09-15): confirmed.
- `hyprctl output create headless [name]` and `output remove <name>`; default name `HEADLESS-N`.
  https://wiki.hypr.land/configuring/core/advanced-configuration/using-hyprctl, https://raw.githubusercontent.com/hyprwm/Hyprland/v0.56.2/src/debug/HyprCtl.cpp (2026-08-05): confirmed.
- `output create` returns before the monitor exists; Hyprland's own tests wait for it.
  https://raw.githubusercontent.com/hyprwm/Hyprland/v0.56.2/hyprtester/src/tests/main/monitor_rules.cpp (2026-08-05): confirmed.
- `output create` refuses a taken name; `output remove` only removes user-created outputs.
  HyprCtl.cpp v0.56.2 (2026-08-05): confirmed.
- Hyprland config moved to Lua in 0.55.
  https://hypr.land/news/update55 (2026-05-09): confirmed.
- Under a Lua config `hyprctl keyword` errors and `hyprctl eval` is the runtime path.
  HyprCtl.cpp v0.56.2; https://github.com/basecamp/omarchy/issues/6968 (2026-08-05): confirmed; Omarchy's "silent no-op" contradicted in part.
- Shane's Hyprland config is Lua (`configType = "lua"`) with no catch-all monitor rule.
  `home/shane/modules/linux/hyprland.nix` (2026-10-26): confirmed (local).
- `hl.monitor` merges onto an existing rule of the same name, and rules are never removed at runtime.
  https://raw.githubusercontent.com/hyprwm/Hyprland/v0.56.2/src/config/lua/bindings/LuaBindingsConfigRules.cpp, `MonitorRuleManager.cpp` (2026-08-05): confirmed.
- Headless outputs are created with one 1920x1080@60 mode.
  https://raw.githubusercontent.com/hyprwm/aquamarine/v0.15.1/src/backend/Headless.cpp (2026-09-17): confirmed.
- A monitor rule with an unadvertised size like 1280x800 is honoured on headless.
  https://raw.githubusercontent.com/hyprwm/Hyprland/v0.56.2/src/output/Monitor.cpp (2026-08-05): confirmed in source, not run; supersedes https://github.com/hyprwm/Hyprland/issues/5415 (closed 2025-04-05).
- A custom headless size worked on the legacy `monitor=` syntax.
  https://github.com/hyprwm/Hyprland/issues/5415 (2024-05-04): unconfirmed on 0.56 Lua.
- Headless frames are timer-driven at the mode's refresh, with no vsync.
  aquamarine `Headless.cpp` (2026-09-17): confirmed.
- A catch-all rule with `disabled = true` would disable new headless outputs.
  `MonitorRuleManager.cpp` v0.56.2 (2026-08-05): confirmed in source.
- Runtime dispatchers `hl.dsp.focus`, `hl.dsp.workspace.move`, `hl.dsp.exec_cmd`.
  `LuaBindingsDispatchers.cpp` v0.56.2 (2026-08-05): confirmed in source, not run.
- `hl.workspace_rule({ workspace, monitor, default })` binds a workspace.
  https://wiki.hypr.land/configuring/core/rules/workspace-rules (undated): syntax confirmed; runtime eval unconfirmed.
- Hyprland documents Sunshine with wlroots capture for a headless setup.
  https://wiki.hypr.land/configuring/extra/virtual-gpu (undated): confirmed.
- After mirroring, a headless output can't be removed and is invisible to wlgrab.
  https://github.com/hyprwm/Hyprland/discussions/16313 (2026-09-20): unconfirmed (one report).
- Headless creation in `exec-once` did nothing under sddm.
  https://github.com/hyprwm/Hyprland/discussions/12063 (2025-10-17): unconfirmed.
- Sunshine maps absolute mouse using the captured output's offset in the whole desktop.
  Sunshine v2026.914 `src/input.cpp`, `wlgrab.cpp` (2026-09-15): confirmed (code); pointer behaviour in practice unconfirmed.
- Practitioners turn the physical monitor off during a stream to keep the pointer on the stream.
  https://github.com/itsmeROK/sunshine-headless-virtual-display, https://github.com/jhonsnake/sunshine-hyprland-virtual-display (undated): unconfirmed.
- Pointer goes off-screen on a Hyprland headless stream.
  https://catwithcode.moe/Blog/2025.03.21_Sunshine_Remote_Headless_Hyprland/Sunshine_Remote_Headless_Hyprland.html (2025-03-21): unconfirmed.
- v2026.914 always paces capture; event-driven capture arrived in #5883 and ships in pre-release v2026.1018.5342.
  https://github.com/LizardByte/Sunshine (master `wlgrab.cpp`) (2026-10-10): confirmed.
- Sunshine's Steam Big Picture example uses detached `setsid steam steam://open/bigpicture` and undo `steam://close/bigpicture`.
  https://docs.lizardbyte.dev/projects/sunshine/master/md_docs_2app__examples.html (undated): confirmed (docs).
- Sunshine's wlroots example changes an existing output's mode with `wlr-xrandr`.
  same page (undated): confirmed as docs; untested on Hyprland 0.56.
- `steam://open/bigpicture` opens Big Picture.
  Valve's Steam browser protocol page (fetch blocked) (undated): unconfirmed.
- Steam Big Picture opens on the wrong monitor, open for about ten years.
  https://github.com/ValveSoftware/steam-for-linux/issues/4178 (2015-12-12): confirmed that the bug exists.
- `stream_audio`, `audio_sink` and `virtual_sink` options exist.
  https://docs.lizardbyte.dev/projects/sunshine/master/md_docs_2configuration.html (undated): confirmed (docs).
- Headless audio via a PipeWire null sink and `PULSE_SINK`.
  https://github.com/daaaaan/sunshine-headless-sway (undated): unconfirmed.
- gamescope has `--backend headless`, `--steam`, `-W/-H`; one blog runs Steam in it for Remote Play.
  https://raw.githubusercontent.com/ValveSoftware/gamescope/master/src/main.cpp, https://bwc9876.dev/blog/headless_steam_remote_play (2026-09-16; undated): flags confirmed; blog unconfirmed.
- Create-on-demand in `do` and destroy in `undo` works on sway and niri.
  https://gist.github.com/pxlrs-dev/4cdfe9f6ff75305bcafdf1dfeb311491, https://gist.github.com/Dregu/4c0dbb2582835e5d95e06c4bf7624e3b (2025-12-11; undated): unconfirmed (not Hyprland).
- SteamOS's per-game Maximum Resolution can fight a 1280x800 Moonlight stream; default fixes it.
  https://github.com/moonlight-stream/moonlight-qt/issues/1405 (2024-09-08): unconfirmed.
- WayDisplay keeps a permanent 1280x800 headless monitor on Hyprland.
  https://blazelight.dev/projects/waydisplay (undated): unconfirmed (snippet only).

## Gaps

- Nothing was run on the desktop. The headless 1280x800 rule, where Steam Big Picture's window lands, and where the pointer goes all need a test by hand.
- The aquamarine and nixpkgs revisions in caboodle's pin weren't checked against the sources read.
- Valve's `steam://` documentation couldn't be fetched.
