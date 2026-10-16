{
  claude-code,
  codex,
  fetchPnpmDeps,
  fetchurl,
  fish,
  lib,
  libsecret,
  lsof,
  patchelf,
  pkg-config,
  pnpm_11,
  rustPlatform,
  src,
  stdenv,
  t3code,
}:

let
  nodeArch =
    {
      x86_64 = "x64";
      aarch64 = "arm64";
    }
    .${stdenv.hostPlatform.parsed.cpu.name};

  pnpm = pnpm_11.override {
    version = "11.10.0";
    hash = "sha256-YgtmBepPYvxWptCphzP0eQcdAyHgPkhrUix+mnRhdDE=";
  };

  # nixpkgs' resource-monitor sidecar derives its sourceRoot from src.name.
  # Flake-input source trees carry no name attribute, so pin the "source"
  # unpack dir name stdenv produces for a /nix/store/*-source directory.
  namedSrc = src // {
    name = "source";
  };

  # The web build's third-party-licenses plugin downloads SPDX licence texts
  # unless they are already cached, and the build sandbox has no network.
  # Keep the revision and version in step with scripts/lib/third-party-licenses.ts.
  spdxLicenseListRevision = "c4a7237ec8f4654e867546f9f409749300f1bf4c";
  spdxLicenseListVersion = "v3.28.0";
  spdxLicenseHashes = {
    "Apache-2.0" = "sha256-iyt7wmfXAL6UCFzSyDA+Atj4ODKLKnMQ3DqIQNPKErs=";
    "BSD-2-Clause" = "sha256-h2hDpwacR4mNECQyo1vjMqRXz3r/gJTMsYqj315jQJI=";
    "BSD-3-Clause" = "sha256-RXYFS3RBfUAh/9ovY7h/3lJ5Hj7ZTu7yznkwJRtDcwE=";
    "CC0-1.0" = "sha256-gdRg6RFSHhS1Ky/Y4Gl5Wscx6JhspYpdKUFdzAHqoSU=";
    "ISC" = "sha256-VJTDV7IdtsBt1r1r1J1ldZINPVNDQE5vVFkWPmjn5Yo=";
    "MIT" = "sha256-fuCJ3MxiW/GLCrHoDgxLysVYeIT1viXZATuK1sYd1Dk=";
    "Unlicense" = "sha256-itR5uQEH/xGJKbe09Fvk/axB/Aq0J6LEIbwwY52X4fs=";
  };
  spdxLicenseCache = lib.concatStrings (
    lib.mapAttrsToList (licenseId: hash: ''
      install -Dm644 ${
        fetchurl {
          url = "https://raw.githubusercontent.com/spdx/license-list-data/${spdxLicenseListRevision}/json/details/${licenseId}.json";
          inherit hash;
        }
      } .generated/third-party-licenses/spdx/${spdxLicenseListVersion}/${licenseId}.json
    '') spdxLicenseHashes
  );

  # SnapShots' Hyprland capture helper. Upstream only builds it in the
  # electron-builder pipeline, not in `build:desktop`.
  hyprlandSnapShot = rustPlatform.buildRustPackage {
    pname = "t3-hyprland-snap-shot";
    version = "0.1.0";
    src = namedSrc;
    sourceRoot = "${namedSrc.name}/native/hyprland-snap-shot";
    cargoHash = "sha256-oki1DAzUJ/8YIFhaJlw2wOukiQMcAaexdJqxDcFXFW4=";
    meta.mainProgram = "t3-hyprland-snap-shot";
  };

  unwrapped = (t3code.unwrapped.override { pnpm_11 = pnpm; }).overrideAttrs (
    finalAttrs: previousAttrs: {
      pname = "vex-code-unwrapped";
      version = "0.0.45-vex.1";
      src = namedSrc;

      patches = (previousAttrs.patches or [ ]) ++ [
        ./patches/spellcheck-system-locale.patch
        ./patches/catppuccin-code-theme.patch
        ./patches/markdown-italics-primary.patch
        ./patches/body-text-follows-theme.patch
      ];

      nativeBuildInputs =
        (previousAttrs.nativeBuildInputs or [ ])
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          patchelf
          pkg-config
        ];
      buildInputs =
        (previousAttrs.buildInputs or [ ])
        ++ lib.optionals stdenv.hostPlatform.isLinux [
          libsecret
          stdenv.cc.cc.lib
        ];

      pnpmDeps = fetchPnpmDeps {
        inherit pnpm;
        inherit (finalAttrs)
          pname
          version
          src
          pnpmWorkspaces
          ;
        fetcherVersion = 4;
        hash = "sha256-oX4tOu20tYO3ci7VvSEL8eFgxAYWp5HlQFSfAWJGJmg=";
      };

      postPatch = ''
        # Keep the nixpkgs package's loopback-only production build patch,
        # adapted to the newer explicit-host source shape.
        substituteInPlace apps/web/vite.config.ts \
          --replace-fail 'const host = explicitHost || "localhost";' \
                         'const host = explicitHost || "127.0.0.1";'

        # pnpm 11 defaults this to "install", which tries to repair the
        # workspace over the network when the build script starts.
        substituteInPlace pnpm-workspace.yaml \
          --replace-fail "packages:" $'verifyDepsBeforeRun: false\n\npackages:'

        ${spdxLicenseCache}
      ''
      + lib.optionalString stdenv.hostPlatform.isDarwin ''
        # Node 24/libuv can abort in kqueue when pnpm rebuilds several native
        # workspaces at once on Darwin. Serialising that rebuild avoids it.
        substituteInPlace pnpm-workspace.yaml \
          --replace-fail "verifyDepsBeforeRun: false" \
                         $'verifyDepsBeforeRun: false\nchildConcurrency: 1\nworkspaceConcurrency: 1'
      '';

      # The nixpkgs build runs Electron unpackaged, so the setup wizard copies
      # the helper from the source tree's cargo output path, not resources.
      postInstall =
        (previousAttrs.postInstall or "")
        + lib.optionalString stdenv.hostPlatform.isLinux ''
          install -Dm755 ${lib.getExe hyprlandSnapShot} \
            "$out"/libexec/t3code/native/hyprland-snap-shot/target/release/t3-hyprland-snap-shot
        '';

      postFixup =
        (previousAttrs.postFixup or "")
        + lib.optionalString stdenv.hostPlatform.isLinux ''
          # node-pty 1.2 ships a generic Linux prebuild rather than compiling
          # it in this derivation, so it has no Nix RUNPATH for libstdc++.
          # Patch only the binary selected by this host; the pnpm tree also
          # contains unused foreign-platform prebuilds.
          mapfile -d "" -t pty_modules < <(
            find "$out/libexec/t3code" \
              -path "*/node-pty/prebuilds/linux-${nodeArch}/pty.node" \
              -print0
          )
          if [ "''${#pty_modules[@]}" -eq 0 ]; then
            echo "node-pty Linux ${nodeArch} prebuild not found" >&2
            exit 1
          fi
          for pty_module in "''${pty_modules[@]}"; do
            chmod u+w "$pty_module"
            patchelf --set-rpath ${
              lib.makeLibraryPath [
                stdenv.cc.cc.lib
                stdenv.cc.libc
              ]
            } "$pty_module"
          done
        ''
        + ''
          wrapProgram "$out/bin/t3" \
            --prefix PATH : ${lib.makeBinPath [ lsof ]}
          wrapProgram "$out/bin/t3code-desktop" \
            --prefix PATH : ${lib.makeBinPath [ lsof ]} \
            --set T3CODE_DISABLE_AUTO_UPDATE 1 \
            --set SHELL ${lib.getExe fish}
        ''
        + lib.optionalString stdenv.hostPlatform.isDarwin ''
          old_app="$out/Applications/T3 Code (Alpha).app"
          vex_app="$out/Applications/Vex Code (Alpha).app"
          old_executable="$old_app/Contents/MacOS/T3 Code (Alpha)"
          vex_executable="$old_app/Contents/MacOS/Vex Code (Alpha)"
          info_plist="$old_app/Contents/Info.plist"

          substituteInPlace "$info_plist" \
            --replace-fail \
              '<string>T3 Code (Alpha)</string>' \
              '<string>Vex Code (Alpha)</string>'
          mv "$old_executable" "$vex_executable"
          mv "$old_app" "$vex_app"
        '';

      passthru = previousAttrs.passthru // {
        inherit hyprlandSnapShot;
      };

      meta = previousAttrs.meta // {
        description = "Shane's personal fork of T3 Code";
        homepage = "https://github.com/shaneplunkett/vex-code";
        downloadPage = "https://github.com/shaneplunkett/vex-code";
        changelog = null;
      };
    }
  );
in
(t3code.override {
  inherit claude-code codex;
  enableClaude = true;
  t3code-unwrapped = unwrapped;
}).overrideAttrs
  { pname = "vex-code"; }
