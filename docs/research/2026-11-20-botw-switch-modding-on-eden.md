# BotW Switch modding on Eden

- **Question:** "Does the mod manager do like easy search install stuffs? Is it worth just doing general research on modding botw?" Scoped to: which popular mods work on Switch 1.6.0, what UKMM + Eden looks like on Linux, and whether anyone has fixed the blurry HUD with UltraCam BotW on emulators.
- **Researched:** 2026-11-20, normal
- **Setup at the time:** Eden 0.2.1 on the desktop, BotW 1.6.0 with both DLC, UltraCam 1.0.1 (`load/01007EF00011E000/UltraCam`), Xbox One UI font mod Western (`load/01007EF00011E000/Xbox UI (Western)`), Zelda's Ballad all-in-one 3.0.2 (`load/01007EF00011E000/Zelda's Ballad` and `load/01007EF00011F001/Zelda's Ballad`). BotW per-game Eden settings: 3x resolution, AA off, Area filter, American English, "BotW Western" input profile with A/B swapped.

## Sub-questions

1. Which popular mods work on Switch 1.6.0 (graphics, QoL, Zelda's Ballad companions)?: answered from mod pages; no archives opened, so file-level conflicts are inferred
2. What does UKMM + Eden look like on Linux (dump, deploy, 1-click, gotchas, exefs mods)?: answered from UKMM and Eden source; nothing was run
3. Has anyone fixed the blurry HUD with UltraCam BotW on emulators?: gap; no documented fix, and the cause is narrowed but unconfirmed

## Claims

### Game versions and tools

- BotW 1.6.0 released 2019-04-25
  - **Source:** https://en-americas-support.nintendo.com/app/answers/detail/a_id/25568/~/how-to-update-the-legend-of-zelda%3A-breath-of-the-wild
  - **Date:** 2019-04-25
  - **Verdict:** confirmed
- BotW 1.9.0 is the newest Switch update, released 2026-02-17
  - **Source:** same Nintendo page
  - **Date:** 2026-02-17
  - **Verdict:** confirmed
- Most Switch mods only work with 1.5.0 or 1.6.0, so 1.9.0 breaks them
  - **Source:** https://zeldamods.org/wiki/Help:Using_mods
  - **Date:** undated
  - **Verdict:** unconfirmed (community wiki; matches mod-page claims)
- UKMM latest release is v0.17.3
  - **Source:** https://github.com/NiceneNerd/UKMM/releases/tag/v0.17.3
  - **Date:** 2026-11-05
  - **Verdict:** confirmed
- BCML latest release is v3.10.8 and its README points to UKMM instead
  - **Source:** https://github.com/NiceneNerd/BCML
  - **Date:** 2023-02-11
  - **Verdict:** confirmed
- Some BNPs can't be installed with UKMM; use a loose-file version when one exists
  - **Source:** https://zeldamods.org/wiki/Help:Tools/UKMM
  - **Date:** undated
  - **Verdict:** confirmed

### Mods: graphics and UI

- HD Texture Pack v1.0 is Switch 1.6.0 only, loose `HDTextures` folder, no merger; needs yuzu's 8GB DRAM option or a custom Ryujinx
  - **Source:** https://gamebanana.com/mods/478224
  - **Date:** 2024-01-11
  - **Verdict:** confirmed; Eden support unverified (Eden has a `memory_layout_mode` setting, seen in its config, not tested)
- BOTW HD Texture Pack (Switch), gamebanana 426598
  - **Source:** https://gamebanana.com/mods/426598
  - **Date:** undated
  - **Verdict:** unconfirmed
- Nexus 4K Texture Pack by HDPacks, tagged Switch
  - **Source:** https://www.nexusmods.com/legendofzeldabreathofthewild/mods/61
  - **Date:** 2024-02-20
  - **Verdict:** unconfirmed (search snippet only)
- ReShade preset for yuzu (Windows, OpenGL)
  - **Source:** https://gamebanana.com/mods/369358
  - **Date:** 2022-04-05
  - **Verdict:** unconfirmed for Linux/Eden
- Full Xbox/PS UI replacement for yuzu/Citron, romfs, replaces the whole UI and tutorials; Standard layout only; no game version stated
  - **Source:** https://gamebanana.com/mods/651656
  - **Date:** 2026-02-08
  - **Verdict:** unconfirmed; overlap with 33340 and Zelda's Ballad is inferred, not file-checked
- Xbox UI Western Layout (full UI) is UKMM only; page cites UKMM v0.17.0-1
  - **Source:** https://gamebanana.com/mods/670522
  - **Date:** 2026-11-19
  - **Verdict:** confirmed; tool version superseded by v0.17.3
- Xbox One UI (font/button glyphs only, Western) replaces `Font/Font_EU.sbfarc` and `Font/Font_US.sbfarc`; it cannot change the floating interaction prompt, which is a layout image
  - **Source:** https://gamebanana.com/mods/33340
  - **Date:** 2020-01-17
  - **Verdict:** confirmed (listing and archive contents); the interaction-prompt limit was observed in play

### Mods: quality of life

- Infinite Durability (1.6.0), Atmosphere SD layout only
  - **Source:** https://gamebanana.com/mods/49134
  - **Date:** 2020-07-26
  - **Verdict:** confirmed for 1.6.0
- Infinite Durability Second Wind 1.6.0 needs 1.6.0, all DLC and Second Wind
  - **Source:** https://gamebanana.com/mods/358220
  - **Date:** 2022-02-16
  - **Verdict:** confirmed
- TRUE Infinite Durability + NG+; no target version stated
  - **Source:** https://gamebanana.com/mods/600836
  - **Date:** 2026-06-03
  - **Verdict:** unconfirmed
- No Friction Shields installs with UKMM
  - **Source:** https://gamebanana.com/mods/49081
  - **Date:** 2023-05-01
  - **Verdict:** confirmed
- Unbreakable Champions' Weapons has a Switch file
  - **Source:** https://gamebanana.com/mods/449772
  - **Date:** 2023-06-13
  - **Verdict:** confirmed
- No slipping in rain edits `TitleBG.pack`, so it conflicts with other `TitleBG.pack` mods (Zelda's Ballad all-in-one ships a `TitleBG.pack`)
  - **Source:** https://gamebanana.com/mods/49090
  - **Date:** 2019-02-26
  - **Verdict:** confirmed; the Zelda's Ballad clash is from its archive listing
- No Loot Boxes is a plain romfs folder at `load/01007EF00011E000/NoLootBoxes/romfs`; no game version stated
  - **Source:** https://gamebanana.com/mods/444097
  - **Date:** 2023-05-17
  - **Verdict:** confirmed for install path
- Clean UI ProHud3000 hides HUD elements rather than sharpening them
  - **Source:** https://gamebanana.com/mods/33344
  - **Date:** 2020-10-13
  - **Verdict:** unconfirmed
- MasterCyclePlus overwrites `AocMainField.pack`; no version stated
  - **Source:** https://gamebanana.com/mods/49145
  - **Date:** 2026-09-13
  - **Verdict:** confirmed for install text
- Relics of the Past (difficulty overhaul, not QoL) has a Switch dev build for UKMM
  - **Source:** https://gamebanana.com/mods/414823
  - **Date:** 2026-07-24
  - **Verdict:** confirmed

### Mods: Zelda's Ballad and companions

- Zelda's Ballad & More all-in-one 3.0.2 bundles Girly Animation Pack v6.3 and Dialogue and Cutscene-Audio Adjustments v2.0.2; 1.6.0 with all DLC only; ships English text as `Bootup_USen.pack` only
  - **Source:** https://gamebanana.com/mods/246725
  - **Date:** 2021-11-17
  - **Verdict:** confirmed (author page and archive contents)
- Girly Animation Pack port is compatible with Zelda's Ballad, final version v10.6, newer than the bundled 6.3; BCML
  - **Source:** https://gamebanana.com/mods/505453
  - **Date:** 2026-03-09
  - **Verdict:** confirmed; "supersedes 6.3" from file names
- Dialogue and Cutscene-Audio Adjustments needs BCML 3.6.2+ and game version 208; already bundled in the all-in-one
  - **Source:** https://gamebanana.com/mods/327683
  - **Date:** 2022-01-05
  - **Verdict:** confirmed; 208 = 1.6.0 mapping unverified
- Zelda's Ballad Amiibo Outfits (Switch)
  - **Source:** https://gamebanana.com/mods/305377
  - **Date:** 2021-11-04
  - **Verdict:** confirmed listing; compatibility with 3.0.2 unverified
- Zelda's Ballad Helm Pack (Switch)
  - **Source:** https://gamebanana.com/mods/305336
  - **Date:** 2021-11-04
  - **Verdict:** confirmed listing; compatibility unverified
- Competition outfits for Zelda's Ballad (BNP)
  - **Source:** https://gamebanana.com/mods/593372
  - **Date:** 2025-05-10
  - **Verdict:** confirmed listing; compatibility unverified
- Zelda's Ballad unofficial standalone port (BNP), an alternative to 246725
  - **Source:** https://gamebanana.com/mods/332300
  - **Date:** 2021-11-03
  - **Verdict:** confirmed listing

### UKMM with Eden on Linux

- Switch dump for UKMM is unpacked RomFS: base folder is base game plus the 1.6.0 update combined, DLC is a separate folder; check for `Actor/Pack` (7000+ files) and `Pack/AocMainField.pack`
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/v0.17.3/book/src/setup/dump-settings.md
  - **Date:** 2026-11-05
  - **Verdict:** confirmed
- Eden's Dump RomFS writes `dump/<tid>/romfs`, applies the installed update and skips mod layers; "Dump RomFS to SDMC" writes into `sdmc/atmosphere/contents/<tid>/romfs`, which Eden then loads as a mod layer (so avoid that one)
  - **Source:** https://git.eden-emu.dev/eden-emu/eden/raw/tag/v0.2.1/src/yuzu/main_window.cpp
  - **Date:** 2026-06-01
  - **Verdict:** confirmed (source)
- Switch deploy output is `01007EF00011E000/romfs` and `01007EF00011F001/romfs`; "With Name" inserts `BreathOfTheWild_UKMM` before `romfs`
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/v0.17.3/crates/uk-content/src/lib.rs
  - **Date:** 2026-11-05
  - **Verdict:** confirmed
- UI labels: With Name = "Emulator", Without Name = "SD Card"; methods Copy, HardLink, Symlink
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/master/crates/uk-manager/src/settings.rs
  - **Date:** undated (master)
  - **Verdict:** confirmed
- For Eden, deploy to `~/.local/share/eden/load` with With Name; Without Name against `load/` would not load
  - **Source:** inferred from Eden's patch_manager.cpp layering and UKMM's lib.rs
  - **Date:** n/a
  - **Verdict:** unconfirmed (not run)
- Symlink deploy makes the deploy target a link to UKMM's merged folder and runs `remove_dir_all` on a real folder already at the target
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/master/crates/uk-manager/src/deploy.rs
  - **Date:** undated (master)
  - **Verdict:** confirmed (source); whether the target is `load/` itself or the per-title folder is unverified, and it matters because `load/` holds every game's mods
- Orphan cleanup only removes files UKMM deployed itself
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/master/crates/uk-manager/src/deploy.rs
  - **Date:** undated (master)
  - **Verdict:** confirmed
- Eden mod root is `$XDG_DATA_HOME/eden/load/<TITLEID>`; each subfolder is one mod with `romfs`, `exefs` or `romfs_ext`, matched case-insensitively on Linux
  - **Source:** https://git.eden-emu.dev/eden-emu/eden/raw/tag/v0.2.1/src/core/file_sys/patch_manager.cpp
  - **Date:** 2026-06-01
  - **Verdict:** confirmed
- In Eden v0.2.1, DLC romfs is patched only from the DLC title id's mod root (`01007EF00011F001`); master adds base-title layering, unreleased
  - **Source:** https://git.eden-emu.dev/eden-emu/eden/raw/tag/v0.2.1/src/core/file_sys/romfs_factory.cpp
  - **Date:** 2026-06-01
  - **Verdict:** confirmed for v0.2.1; superseded on master only
- UKMM merges UKMM packs, BCML BNPs and RomFS folders; it has no exefs support, so UltraCam stays in its own folder beside `BreathOfTheWild_UKMM`
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/v0.17.3/book/src/using-mods.md
  - **Date:** 2026-11-05
  - **Verdict:** confirmed
- GameBanana 1-click uses the `bcml:` URL scheme; UKMM ships no `.desktop` file, nixpkgs registers `x-scheme-handler/bcml` with `Exec=ukmm %u`
  - **Source:** https://github.com/NixOS/nixpkgs/blob/master/pkgs/by-name/uk/ukmm/package.nix
  - **Date:** 2026-11-19
  - **Verdict:** confirmed (source, not clicked)
- nixpkgs `ukmm` is 0.17.3 on master, bumped from 0.17.1 on 2026-11-19
  - **Source:** same nixpkgs file
  - **Date:** 2026-11-19
  - **Verdict:** confirmed; whether caboodle's pin has it is unchecked
- UKMM 0.17.3 forces scale 1.0 on Wayland; a fix is under Unreleased; `WINIT_X11_SCALE_FACTOR=1.0` is the documented workaround for X11 scaling
  - **Source:** https://github.com/NiceneNerd/UKMM/blob/master/CHANGELOG.md
  - **Date:** undated (Unreleased)
  - **Verdict:** superseded by an unreleased fix

### Blurry HUD with UltraCam

- UltraCam's resolution option makes the game render at the chosen size rather than upscale
  - **Source:** https://github.com/MaxLastBreath/nx-optimizer (README)
  - **Date:** 2026-10-16
  - **Verdict:** confirmed; says nothing about the HUD
- UltraCam BotW resolution choices are 1280x720 to 2048x1152, default 1920x1080; over 1440p needs extended memory
  - **Source:** https://github.com/MaxLastBreath/nx-optimizer/blob/main/src/PatchInfo/Breath%20Of%20The%20Wild/Options.json
  - **Date:** 2026-10-16
  - **Verdict:** confirmed
- Quality Improvements disables FXAA, FSR and dynamic resolution and should be on with high resolution
  - **Source:** same Options.json
  - **Date:** 2026-10-16
  - **Verdict:** confirmed
- The ini comment "1152x2048" is transposed; the max is 2048x1152
  - **Source:** same repo plus https://www.patreon.com/MaxLastBreath/posts/ultracam-3-0-6-1-111718882
  - **Date:** 2026-10-16
  - **Verdict:** confirmed
- Eden only rescales colour render targets taller than 288 px, single-mip, block depth 0; if any bound target in a batch fails, the whole batch drops to 1x
  - **Source:** https://git.eden-emu.dev/eden-emu/eden (texture_cache.h `RescaleRenderTargets`, image_info.cpp `RescaleHeightThreshold`)
  - **Date:** 2026-11-20 (master)
  - **Verdict:** confirmed; whether BotW's HUD hits this path is unverified
- NX Optimizer FAQ: on Eden/Citron-Neo, NX Optimizer sets the emulator to 0.75x instead of 1.00x, so the game looks blurry; implies 1.00x is the expected emulator setting
  - **Source:** https://www.nxoptimizer.com/guides/faq
  - **Date:** undated
  - **Verdict:** unconfirmed; only applies when NX Optimizer writes the setting, which this setup doesn't use
- NX Optimizer issue: Eden "has an issue with the resolution index"
  - **Source:** https://github.com/MaxLastBreath/nx-optimizer/issues/291
  - **Date:** 2026-02 (approx)
  - **Verdict:** unconfirmed
- Issue: custom ini resolution on Ryujinx looks like 720p with aliasing; open, no reply
  - **Source:** https://github.com/MaxLastBreath/nx-optimizer/issues/183
  - **Date:** 2024-12-07
  - **Verdict:** unconfirmed
- Issue "Resolution Mod only applies to UI" (Sudachi) closed after a game update; looks like a version mismatch
  - **Source:** https://github.com/MaxLastBreath/nx-optimizer/issues/196
  - **Date:** 2025-01-25
  - **Verdict:** unconfirmed
- Other UltraCam BotW issues about the HUD are aspect-ratio stretching (#253, #101) or heat haze (#297), not HUD blur
  - **Source:** https://github.com/MaxLastBreath/nx-optimizer/issues/253
  - **Date:** 2025-10-12
  - **Verdict:** confirmed; off-target
- BotW on Switch uses dynamic resolution
  - **Source:** https://www.digitalfoundry.net/articles/digitalfoundry-2017-zelda-breath-of-the-wild-uses-dynamic-resolution-scaling
  - **Date:** 2017
  - **Verdict:** confirmed; nothing on the HUD
- "Switch UI always renders in 720p" is about the Switch system UI, not BotW's HUD
  - **Source:** https://gamingbolt.com/nintendo-switch-ui-always-renders-in-720p
  - **Date:** 2017-03-02
  - **Verdict:** unconfirmed; off-target
- Reddit threads on blurry BotW HUD (r/yuzu 1v7dc8f, r/cemu pyfxvw) exist but were blocked
  - **Source:** https://www.reddit.com/r/yuzu/comments/1v7dc8f/why_does_my_zelda_look_like_crap_ever_since_i
  - **Date:** undated
  - **Verdict:** unconfirmed (snippet only)

## Gaps

- No source says what size BotW's HUD render targets are, so whether the HUD falls into Eden's unscaled path is unknown. A RenderDoc capture of one HUD draw would settle it.
- How UltraCam's Width/Height stack with Eden's multiplier wasn't checked in code.
- UKMM's symlink deploy target (whole `load/` vs a per-title folder) wasn't confirmed, and nothing was run.
- Whether Eden follows symlinks inside `load/`, and Eden support for the HD texture pack's 8GB mode, are untested.
- The second DLC's title id is unverified; Eden's Dump RomFS dialog lists it.
- Reddit and GBAtemp pages were blocked, so community "must-have" lists come from snippets only.
- No mod archives other than Zelda's Ballad and Xbox One UI were opened, so other conflicts are inferred from page text.
