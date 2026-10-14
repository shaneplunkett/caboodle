# Evaluating, building remotely, and delivering config

_Researched 1 October 2026. Tool versions and project status are a
point-in-time snapshot. Timings were measured on `desktop` with local Nix
2.34.8 and nh 4.3.2. hetzvps was decommissioned on 5 October 2026, so its
sections no longer apply._

## Verdict

**1. Fast feedback while editing.** The common pattern is to put every
host's toplevel into flake `checks`, filtered by system. Day to day, people
evaluate one host's `.drv` path, and CI runs `nix flake check` or
`nix-fast-build`. Bare `nix flake check` is weaker than it looks: it only
shallow-checks `nixosConfigurations` and skips `darwinConfigurations`
entirely. For Shane, the cheapest win is to use
`nix path-info --derivation` instead of `nix eval … drvPath`. The first run
takes the same ~15s, but an unchanged tree after that, dirty or not, comes
back in 0.03s from the eval cache. Darwin hosts already evaluate on the
desktop, because the config has no import-from-derivation (IFD).

**2. Building for a different system type.** The usual options are:

- a Nix remote builder (`nix.buildMachines`);
- `nh … --build-host` / `nixos-rebuild --build-host`;
- `nix build --eval-store auto --store ssh-ng://host`;
- nix-darwin's `nix.linux-builder` VM on a Mac.

All of them work on an uncommitted tree. For Shane, `nh darwin build . -H
mini-server --build-host <alias>` could replace the rsync in
`scripts/darwin-build.sh`, and evaluation would stay on the desktop. One SSH
fix is needed first: the `mini` alias sets `RemoteCommand`, and that breaks
every Nix-over-SSH tool.

**3. Getting config onto machines.**

- Push: `nh`/`nixos-rebuild --target-host`, deploy-rs, Colmena, clan.
- Pull: `system.autoUpgrade`, comin, or a timer that switches to a store
  path CI already built.

For Shane's hosts:

- hetzvps: push with `nh os switch --target-host`.
- An always-on host that should pull: comin is the one tool that covers
  NixOS and nix-darwin both.
- Desktop and laptop: keep switching by hand.

Avoid Garnix, which shut down on 15 July 2026. Avoid deploy-rs for the Macs
until its darwin rollback bug is fixed.

## 1. Fast feedback while editing

### Evaluate one host

Evaluating a host's `.drv` path runs the whole module system: assertions,
option types, every derivation in the graph instantiated. Nothing gets built
or downloaded.

```sh
# NixOS
nix eval --raw .#nixosConfigurations.desktop.config.system.build.toplevel.drvPath
# nix-darwin: `system` is config.system.build.toplevel
nix eval --raw .#darwinConfigurations.mini-server.system.drvPath
```

([eval.md](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/nix/eval.md),
[nix-darwin eval-config.nix L88](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/eval-config.nix#L88))

**`nix eval` never hits the eval cache. `nix path-info --derivation` does.**
`nix eval` forces the value through an uncached cursor
([installable-flake.cc L144-147](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/libcmd/installable-flake.cc#L144-L147),
[eval-cache.cc L448-450](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/libexpr/eval-cache.cc#L448-L450)).
`build`, `path-info` and `--dry-run` use the cached path. Measured on this
repo:

| Command (desktop) | 1st run | 2nd run |
|---|---|---|
| `nix eval --raw …toplevel.drvPath` | 15.8s | 15.5s |
| `nix path-info --derivation .#…toplevel` | 15.6s | **0.03s** |
| same, dirty tree | 16.7s | 0.03s (any edit resets it to ~16.8s) |

The cache has worked on dirty git trees since Nix 2.26
([#11992](https://github.com/NixOS/nix/pull/11992)). It's keyed on HEAD plus
a hash of the modified files, and it's off if the repo has submodules
([git.cc L1097-1122](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/libfetchers/git.cc#L1097-L1122)).
There is no incremental eval, so any edit costs a full re-eval.

`ryan4yin/nix-config` wraps this as `just eval-host`
([Justfile L23-34](https://github.com/ryan4yin/nix-config/blob/1546e54bb212b7cb1b1b7e189a9376135d8f219a/Justfile#L23-L34)).

### Darwin evaluates on Linux

`nix eval --raw .#darwinConfigurations.mini-server.system.drvPath` returned in
7.7s on the desktop, and `Shanes-MacBook-Pro` evaluated too. Evaluation is
just Nix code. Only *building* needs the right system.

The thing that would break this is IFD. IFD makes evaluation stop and build
something
([IFD docs](https://github.com/NixOS/nix/blob/2.34.8/doc/manual/source/language/import-from-derivation.md)),
and a darwin IFD can't be built on Linux. Passing
`--option allow-import-from-derivation false` makes Nix throw on any IFD
([eval-settings.hh L210-218](https://github.com/NixOS/nix/blob/2.34.8/src/libexpr/include/nix/expr/eval-settings.hh#L210-L218)).
That makes it a cheap guard to keep the darwin eval Linux-safe.

### `nix flake check` and its gaps

([flake-check.md](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/nix/flake-check.md))

- For `nixosConfigurations`, it forces `toplevel` and checks that it is a
  derivation. It does **not** compute `drvPath`, so errors deeper in the
  graph can slip through
  ([flake.cc L530-542](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/nix/flake.cc#L530-L542)).
- It doesn't evaluate `darwinConfigurations` or `homeConfigurations` at all.
  Both sit on a "known but unchecked" list
  ([L782-787](https://github.com/NixOS/nix/blob/2c73b59da29606068c0c98db015dd3a66955525d/src/nix/flake.cc#L782-L787)).
- It skips other systems' outputs unless you pass `--all-systems`. On this
  repo it printed exactly that, omitting aarch64-darwin and aarch64-linux, in
  15.4s.
- `--no-build --all-systems` evaluates every system's checks without
  building anything.
- 2.32 skips checks whose outputs are already substitutable. 2.35 adds
  `--print-out-paths` and `--out-link`.

### Wrapping hosts in `checks`

What actually makes `nix flake check` meaningful for a config repo is this:

```nix
checks.<system>."nixos-<h>"  = self.nixosConfigurations.<h>.config.system.build.toplevel;
checks.<system>."darwin-<h>" = self.darwinConfigurations.<h>.system;
```

Each entry is filtered to hosts whose `hostPlatform.system` matches.

- **Mic92/dotfiles** does it by hand in flake-parts:
  [checks/flake-module.nix](https://github.com/Mic92/dotfiles/blob/07703fdfd7341ca4101ca609b22f56af8e535d81/checks/flake-module.nix).
- **nix-community/infra** turns all darwin and NixOS configs into `host-<n>`
  checks:
  [flake.nix L120-140](https://github.com/nix-community/infra/blob/ee149f3196dcb3585a02b0e9b48ba8d0e1bf7322/flake.nix#L120-L140).
- **NixOS/infra** groups hosts by architecture so CI can run one
  `nix-fast-build --skip-cached` per arch:
  [checks/flake-module.nix](https://github.com/NixOS/infra/blob/8732ddf3fa08a58034fe6c5100de538160d03cfd/checks/flake-module.nix),
  [ci.yml](https://github.com/NixOS/infra/blob/8732ddf3fa08a58034fe6c5100de538160d03cfd/.github/workflows/ci.yml).
- **numtide/blueprint** generates these checks automatically
  ([lib/default.nix L727-790](https://github.com/numtide/blueprint/blob/8be75245e274a789b87cc4df542abbcd8c5e7f93/lib/default.nix#L727-L790)).

### Diffing what changed

- **nh 4.2+** shows a `dix` closure diff on build and switch (`--diff
  auto|always|never`). 4.4 added remote diffs
  ([CHANGELOG @v4.4.2](https://github.com/nix-community/nh/blob/1ccb0bf461a31626cb51c3dc3ed817c81c40e310/CHANGELOG.md)).
  dix now lives at [manic-systems/dix](https://github.com/manic-systems/dix).
- **`nixos-rebuild --diff`** arrived in 26.05
  ([commit 30cb939](https://github.com/NixOS/nixpkgs/commit/30cb9399cc7e42e31bc2db104a49ac9d5e0544a7)).
- **`nix store diff-closures old new`** is built into Nix.
- **[nix-diff](https://github.com/Gabriella439/nix-diff)** explains why two
  `.drv` files differ. Use it when something rebuilds and you don't know why.

### Multi-host and parallel tools

- **[nix-fast-build](https://github.com/Mic92/nix-fast-build/blob/2.0.4/README.md)**
  2.0.4: starts each build as soon as its attribute finishes evaluating.
  - Flags: `--skip-cached`, `--eval-workers`, `--remote` (eval and build on
    another host), `--store ssh-ng://`.
  - 2.0 replaced nom with its own TUI.
- **[nix-eval-jobs](https://github.com/NixOS/nix-eval-jobs/blob/v2.35.4/README.md)**
  (now under NixOS): parallel workers with memory caps and streaming JSON.
- **Determinate Nix** only: `eval-cores = 0` gives parallel eval
  ([v3.11.0 notes](https://github.com/DeterminateSystems/nix-src/blob/6468ca430b298865100b753ec21687aba457a05c/doc/manual/source/release-notes-determinate/v3.11.0.md)),
  and `lazy-trees = true` is opt-in.

### Tests, LSP, formatting

- **[nixd](https://github.com/nix-community/nixd/blob/2.9.3/nixd/docs/configuration.md)**
  2.9.3 can complete options per config. Set
  `options.nixos.expr = "(builtins.getFlake (builtins.toString ./.)).nixosConfigurations.desktop.options"`,
  and the same with `darwinConfigurations.<h>.options`.
- **[nix-unit](https://github.com/nix-community/nix-unit/blob/v2.35.1/README.md)**
  covers library logic.
  [namaka](https://github.com/nix-community/namaka) is effectively in
  maintenance mode.
- **NixOS VM tests:**
  `pkgs.testers.runNixOSTest`, or `nh os build-vm --run` for a quick check of
  how a host behaves.
- **Formatting and linting:**
  - [treefmt-nix](https://github.com/numtide/treefmt-nix) or
    [git-hooks.nix](https://github.com/cachix/git-hooks.nix) both feed
    `checks`.
  - nixfmt v1.5.0 is the official formatter. `nixfmt-rfc-style` is now just
    an alias.
  - nixpkgs `statix` now builds from the molybdenumsoftware fork
    ([readme](https://github.com/oppiliappan/statix/blob/a5292554eddc5aebae8b66a0ebe37a4aa5720442/readme.md)).

## 2. Building for a different system type

### Shane's SSH alias blocks all of these first

`ssh-ng://mini`, `nix copy` and nh's `--build-host` all run `ssh mini
<command>`. The `mini` alias sets `RemoteCommand fish -l`, and OpenSSH
aborts when a command-line command and `RemoteCommand` are both set
([ssh.c L1363](https://github.com/openssh/openssh-portable/blob/87f0cd1892e501f835dd210abea5461807c8deba/ssh.c#L1363-L1364)).
`scripts/darwin-build.sh` already works around this with `-o
RemoteCommand=none`. There are two general fixes:

- Add a second alias, such as `mini-nix`, without `RemoteCommand` or
  `RequestTTY`.
- Or export `NIX_SSHOPTS="-o RemoteCommand=none -o RequestTTY=no"`. Nix reads
  it ([ssh.cc L57](https://github.com/NixOS/nix/blob/2.34.8/src/libstore/ssh.cc#L57)),
  and nh reads `NH_SSHOPTS`, falling back to `NIX_SSHOPTS`
  ([remote.rs L690](https://github.com/nix-community/nh/blob/v4.4.2/crates/nh-remote/src/remote.rs#L690)).

### Options

| Approach | Eval happens on | Needs commit? | Setup |
|---|---|---|---|
| `nh darwin build . -H mini-server --build-host mini-nix` | desktop | no | SSH alias only |
| `nix build --eval-store auto --store ssh-ng://mini-nix .#…` | desktop | no | SSH alias only |
| Mini as a `nix.buildMachines` entry on the desktop | desktop | no | root key file, daemon config |
| rsync + nh on the mini (current `darwin-build.sh`) | mini | no | none; mini needs private inputs |
| `nix flake archive --to ssh-ng://mini`, then build there | mini | no | SSH alias only |
| binfmt `aarch64-linux` on the desktop | desktop | no | one option; slow |
| nixbuild.net | – | no | Linux targets only, so no darwin |
| Garnix | – | yes | **shut down 2026-07-15** |

**nh `--build-host`** (v4.3.0+) evaluates the `drvPath` locally, copies the
derivation to the host, builds it there and copies the result back
([remote.rs L1480](https://github.com/nix-community/nh/blob/v4.4.2/crates/nh-remote/src/remote.rs#L1480)).

- `nh os` has `--build-host` and `--target-host`.
- `nh darwin` has `--build-host` only. `target_host` is hard-coded to `None`
  ([darwin.rs L107-111](https://github.com/nix-community/nh/blob/v4.4.2/crates/nh-darwin/src/darwin.rs#L107-L111)).
- Pass `-H` explicitly, since it defaults to the local hostname.
- Don't run `nh darwin switch` from Linux.

**`--store ssh-ng://` with `--eval-store auto`** evaluates locally and builds
natively on the remote, and nothing gets copied back. Nix 2.34 fixed eval
failures with `ssh-ng://` eval stores
([rl-2.34 L387](https://github.com/NixOS/nix/blob/2.34.8/doc/manual/source/release-notes/rl-2.34.md#L387)).
Out-links are silently skipped for non-local stores
([command.cc L441-446](https://github.com/NixOS/nix/blob/2.34.8/src/libcmd/command.cc#L441-L446)),
so use `--print-out-paths`.

**Remote builders** let plain `nix build` of a darwin output just work from
Linux. Each builder is one line:
`URI systems sshKey maxJobs speedFactor supportedFeatures mandatoryFeatures hostKey`
([worker-settings.hh L135-200](https://github.com/NixOS/nix/blob/2.34.8/src/libstore/include/nix/store/worker-settings.hh#L135-L200)).
The catches
([distributed-builds.md](https://github.com/NixOS/nix/blob/2.34.8/doc/manual/source/advanced-topics/distributed-builds.md)):

- The daemon runs as root and needs a key with no passphrase. It can't use
  ssh-agent, so rbw is out and the key has to be a file on disk.
- The remote user must be a trusted user. `shane` already is on the mini,
  via `modules/common/nix-settings.nix`.
- `protocol` defaults to `"ssh"` on NixOS
  ([nix-remote-build.nix](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/nixos/modules/config/nix-remote-build.nix#L77-L220))
  and on nix-darwin, so set `"ssh-ng"`.
- Set `builders-use-substitutes = true`.

Mic92 does this:
[nixosModules/remote-builder.nix](https://github.com/Mic92/dotfiles/blob/07703fdfd7341ca4101ca609b22f56af8e535d81/nixosModules/remote-builder.nix).

```nix
nix.distributedBuilds = true;
nix.settings.builders-use-substitutes = true;
nix.buildMachines = [{
  hostName = "mini"; sshUser = "shane"; protocol = "ssh-ng";
  sshKey = "/etc/nix/mini-builder_ed25519"; # root-readable, no passphrase
  systems = [ "aarch64-darwin" ]; maxJobs = 12; speedFactor = 2;
  supportedFeatures = [ "big-parallel" ];
  publicHostKey = "<base64 of the mini's host key>";
}];
```

### `nix.linux-builder` on the mini (for aarch64-linux / hetzvps)

nix-darwin runs a small NixOS VM and registers it as a builder
([linux-builder.nix](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/modules/nix/linux-builder.nix)).
It requires `nix.enable`, so it can't be used with Determinate Nix.

- **QEMU builder (the default):** aarch64-linux runs natively on Apple
  silicon. x86_64-linux is emulated, which is slow.
- **`pkgs.darwin.linux-builder-vz`:** new on unstable from 2026-07-21. It uses
  Virtualization.framework with Rosetta, so x86_64-linux is translated rather
  than emulated, and it drops in on the same port
  ([docs L86-134](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/doc/packages/darwin-builder.section.md#L86-L134)).
  The repo's nixpkgs lock already includes it.
- **Security:** it ships a publicly known host key
  ([docs L4](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/doc/packages/darwin-builder.section.md#L4)).
  The QEMU port forward sets no host address, so port 31022 is probably
  reachable on every interface, Tailscale included.
- **Chaining desktop → mini → VM doesn't work by listing the mini as an
  aarch64-linux builder.** The build hook only sends a bare derivation
  ([build-remote.cc L303-325](https://github.com/NixOS/nix/blob/2.34.8/src/nix/build-remote/build-remote.cc#L303-L325)),
  so the mini's daemon won't forward it to its VM. There are two ways that do
  work:
  - Give the desktop a root SSH alias with `ProxyJump mini`,
    `HostName localhost` and `Port 31022`, and register it as a builder.
  - Or run `nix build --eval-store auto --store ssh-ng://mini-nix
    .#nixosConfigurations.hetzvps…`. This is inferred from the source and
    hasn't been tested.

lovesegfault runs `linux-builder` with `ephemeral = true`
([darwin/hayek](https://github.com/lovesegfault/nix-config/blob/a32b64e0dd85e49c403231c10a176759d889a5fe/configurations/darwin/hayek/default.nix#L36-L55)).

### binfmt emulation and cross-compiling

- **binfmt:** `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` registers
  qemu-user and adds the system to `extra-platforms`
  ([binfmt.nix](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/nixos/modules/system/boot/binfmt.nix#L189-L225)).
  - It's several times to an order of magnitude slower. That's fine for small
    leaf builds, but a native builder is better for anything big.
  - The desktop doesn't have it yet.
  - ryan4yin uses it with `preferStaticEmulators = true`
    ([idols-ruby](https://github.com/ryan4yin/nix-config/blob/1546e54bb212b7cb1b1b7e189a9376135d8f219a/hosts/idols-ruby/default.nix#L26-L32)).
- **Cross-compiling** (`nixpkgs.buildPlatform`) changes every hash, so
  cache.nixos.org has almost nothing for you. It's rarely worth it for a host
  config.

## 3. Getting config onto machines

### Push

- **`nh os switch --target-host` / `nixos-rebuild --target-host`.** This is
  the lightest option. nixos-rebuild is now the Python rewrite only: the
  Bash version was removed in 26.05
  ([rl-2605 L333](https://github.com/NixOS/nixpkgs/blob/b4fd65b198c599cbe814fcb9f42d25d021595ec9/nixos/doc/manual/release-notes/rl-2605.section.md#L333)).
  It uses `--sudo` / `--ask-sudo-password`; `--use-remote-sudo` is
  deprecated. Misterio77 wraps it in a
  [deploy.sh](https://github.com/Misterio77/Foundry/blob/3703ecf71e8025adf5470e63aa42da7ece9db5f7/deploy.sh).
- **nix-darwin has no remote switch.** `darwin-rebuild` has no
  `--target-host`
  ([darwin-rebuild.sh](https://github.com/nix-darwin/nix-darwin/blob/4cff07de74b50e64bdd68cd4e722ab5b6b35ee48/pkgs/nix-tools/darwin-rebuild.sh#L49-L131)),
  and neither does `nh darwin`. A manual remote switch means running
  `nix-env -p /nix/var/nix/profiles/system --set $P` and then `$P/activate`
  over SSH. Activating over SSH can abort at the LaunchAgent reload
  (nix-darwin#1758).
- **[deploy-rs](https://github.com/serokell/deploy-rs/blob/cf64c8cbadd9b13ea79ba7720aa2930500f2ece7/README.md)**
  is active but has no releases. Its standout feature is *magic rollback*:
  the target reverts unless the deployer reconnects and confirms in time.
  **Magic rollback is broken on macOS**: every deploy rolls back because
  `/tmp` resolves to `/private/tmp`. The fix is still an open PR
  ([#404](https://github.com/serokell/deploy-rs/pull/404)); the workaround is
  `tempPath = "/private/tmp"`.
- **[Colmena](https://github.com/nix-community/colmena)** moved to
  nix-community and released v0.5.0 on 2026-09-22, its first release in three
  years. That release makes direct flake eval the default. It has tags
  (`--on @tag`) and `deployment.keys`, but no darwin targets and no magic
  rollback. ryan4yin uses it for a homelab
  ([Justfile L195-239](https://github.com/ryan4yin/nix-config/blob/1546e54bb212b7cb1b1b7e189a9376135d8f219a/Justfile#L195)).
- **[clan](https://clan.lol/docs/26.05/releases/26-05)** 26.05 covers
  deploys, secrets ("vars") and inventory, and supports darwin. Adopting it
  means moving off agenix. Mic92 uses it
  ([inventory.nix](https://github.com/Mic92/dotfiles/blob/07703fdfd7341ca4101ca609b22f56af8e535d81/machines/inventory.nix)).
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere/blob/3c6e0cc24fbc69b97a22cf09bb6ca361354e0490/docs/cli.md)**
  is for first installs only: kexec, then disko, then install.
  `--extra-files` is handy for seeding the agenix host key.
- **Stale or not ready:** morph (maintenance only), bento (last commit
  2024-12), krops, NixOps4 (still "in development").

### Pull

- **`system.autoUpgrade`** (NixOS only)
  ([auto-upgrade.nix](https://github.com/NixOS/nixpkgs/blob/449715474577e86dab88b3ebc99341f76beace03/nixos/modules/tasks/auto-upgrade.nix)):
  - Set `flake = "github:…"` and `upgrade = false` so it respects the
    lockfile.
  - Other options: `operation` (`switch` or `boot`), `dates`,
    `randomizedDelaySec`, `allowReboot` with `rebootWindow`, and
    `runGarbageCollection`.
  - It runs as root, so a private flake needs a root deploy key on every
    host.
  - The `--update-input` flag in its docs is deprecated.
  - There's no rollback beyond normal generations.
- **nix-darwin has no autoUpgrade.** A PR is open
  ([#1682](https://github.com/nix-darwin/nix-darwin/pull/1682)). People write
  a `launchd.daemons` job that runs `darwin-rebuild switch --flake
  github:…`, for example
  [ImLunaHey/auto-upgrade.nix](https://github.com/ImLunaHey/nixos-configs/blob/56b7ccf58b9229a7848283830df554ef75f09f09/darwin/auto-upgrade.nix).
- **[comin](https://github.com/nlewo/comin)** v0.14.0 (2026-07):
  - Polls git and switches. Has NixOS and nix-darwin modules (darwin since
    v0.8.0).
  - `testing-<hostname>` branches deploy with `switch-to-configuration test`,
    so a reboot reverts them
    ([howtos](https://github.com/nlewo/comin/blob/9668b02a453dd81176ae426274a017964be1bed3/docs/howtos.md)).
  - Also: per-branch operation, `postDeploymentCommand`, commit-signature
    checks, SSH deploy-key auth (new in v0.14), and a Prometheus exporter
    ([features.md](https://github.com/nlewo/comin/blob/9668b02a453dd81176ae426274a017964be1bed3/docs/features.md)).
  - No Home Manager support, no automatic rollback. Each host evaluates and
    builds for itself.
- **Switching to a store path CI already built** (the host doesn't evaluate):
  - **nix-community/infra:** a five-minute timer looks up the path buildbot
    built and runs `nixos-rebuild switch --store-path $p` (new in 26.05). If
    the kernel, initrd or systemd changed, it uses `boot` and a reboot instead
    ([update.bash](https://github.com/nix-community/infra/blob/ee149f3196dcb3585a02b0e9b48ba8d0e1bf7322/modules/nixos/common/update.bash)).
  - **Misterio77:** does the same against Hydra
    ([hydra-auto-upgrade.nix](https://github.com/Misterio77/nix-config/blob/3703ecf71e8025adf5470e63aa42da7ece9db5f7/modules/nixos/hydra-auto-upgrade.nix)).
  - **Hosted versions:** [Cachix Deploy](https://docs.cachix.org/deploy/index.html)
    (paid; it has a `rollbackScript`) and
    [FlakeHub `fh apply`](https://github.com/DeterminateSystems/fh#apply-configurations-to-the-current-system)
    (paid for private flakes).

### CI plus a binary cache

- **GitHub runners**
  ([reference](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)):
  `ubuntu-24.04-arm` builds aarch64-linux, and `macos-latest` (M1) builds
  aarch64-darwin.
- **Cost on private repos**
  ([billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)):
  the free plan includes 2,000 minutes. After that, macOS costs $0.062/min,
  about 10× Linux.
- **Example:** lovesegfault builds every host on all three runner types and
  pushes to Cachix
  ([ci.yaml](https://github.com/lovesegfault/nix-config/blob/a32b64e0dd85e49c403231c10a176759d889a5fe/.github/workflows/ci.yaml)).
- **Caches:**
  - [cachix-action](https://github.com/cachix/cachix-action) v17.
  - Self-hosted [Attic](https://github.com/zhaofengli/attic), which could run
    on the mini or hetzvps.
  - magic-nix-cache only shares between CI runs, so machines can't pull from
    it.
  - Garnix is gone; its user data was deleted
    ([Discourse](https://discourse.nixos.org/t/garnix-is-shutting-down-not-oc/77895)).
- **Lock bumps:**
  [update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)
  v29.

### Rollback and safety

| Mechanism | What it gives you |
|---|---|
| deploy-rs | Magic and auto rollback (broken on darwin until #404 lands) |
| comin | `testing-<host>` branches use `test`, so a reboot reverts |
| autoUpgrade | `operation = "boot"`, `allowReboot` + `rebootWindow`, `randomizedDelaySec` |
| CI store-path pull | Switch inhibitors force boot + reboot for kernel/systemd changes |
| Everywhere | `nh os rollback`, `nixos-rebuild --rollback`, `darwin-rebuild --rollback` |

## Fits Shane's setup

Ranked by payoff for effort, smallest first.

1. **Swap `nix eval` for `nix path-info --derivation`** in any eval helper.
   Re-checks on an unchanged tree come back instantly. *Minutes.*
2. **Add a darwin eval guard to `scripts/check.sh`.** Run `nix eval --raw
   .#darwinConfigurations.<h>.system.drvPath --option
   allow-import-from-derivation false` for both Macs. That catches darwin
   breakage from the desktop in ~8s and keeps it Linux-safe. *Minutes.*
3. **Add a `mini-nix` SSH alias** (no `RemoteCommand` or `RequestTTY`). It
   unlocks every remote-build option below. *Minutes.*
4. **Try `nh darwin build . -H mini-server --build-host mini-nix`** in place
   of rsync in `darwin-build.sh`. Eval stays on the desktop, so the mini no
   longer needs the private inputs. Switching still happens on the Mac
   itself. *Small.*
5. **Wrap every host in `checks`**, following the Mic92 / nix-community/infra
   pattern, so `nix flake check --all-systems --no-build` really covers all
   four hosts. *Small.*
6. **hetzvps:** `nh os switch . -H hetzvps --build-host hetzvps --target-host
   hetzvps` builds natively on aarch64 with no extra setup. `linux-builder-vz`
   on the mini is an option if you want hetzvps closures built at home.
   *Small to medium.*
7. **Automation, if wanted:** comin on the mini and/or hetzvps. It's the one
   tool that covers both NixOS and darwin, and `testing-<host>` branches make
   risky changes safe to try. It does need a deploy key for the private
   inputs on each host. The heavier but more robust route is CI or the mini
   building closures into Attic, with hetzvps pulling via `nixos-rebuild
   --store-path`. *Medium to large.*
8. **Leave the desktop and laptop manual.** Auto-switching the machine you're
   editing on, or a laptop that's often asleep, is more surprise than help.
