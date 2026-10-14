{ inputs, rootPath }:
let
  inherit (inputs)
    nixvim
    catppuccin
    nix-index-database
    ;

  # Single constructor for the project package set in pkgs/. The platform is
  # passed as a system string so the overlay can derive it from prev (avoiding
  # recursion through final.stdenv) while the flake packages output passes the
  # forAllSystems value.
  mkProjectPackages =
    system: pkgs:
    import (rootPath + /pkgs) {
      inherit pkgs;
      vexCodeSrc = inputs.vex-code;
      isLinux = inputs.nixpkgs.lib.hasSuffix "-linux" system;
      isX86Linux = system == "x86_64-linux";
    };
  palette = import ./palette.nix;
  typography = import ./typography.nix;
in
{
  inherit mkProjectPackages palette typography;

  mkOverlays =
    extras:
    [
      (
        _final: prev:
        let
          system = prev.stdenv.hostPlatform.system;
          aiPackages = inputs.llm-agents.packages.${system} or { };
        in
        (prev.lib.optionalAttrs (builtins.hasAttr "codex" aiPackages) {
          inherit (aiPackages) codex;
        })
        // (prev.lib.optionalAttrs (builtins.hasAttr "claude-code" aiPackages) {
          inherit (aiPackages) claude-code;
        })
        // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
          # Keep Numtide's runtime wrappers and cache-backed derivations intact.
          inherit (aiPackages) chatgpt claude-desktop;
        }
      )
      (final: prev: mkProjectPackages prev.stdenv.hostPlatform.system final)
      (
        final: prev:
        let
          electron = inputs.electron-nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system}.electron_43;
        in
        {
          bitwarden-desktop =
            (prev.bitwarden-desktop.override {
              electron_43 = electron;
            }).overrideAttrs
              (old: {
                # Apple's ld from cctools 1010.6 traps while processing stubs for
                # Bitwarden's desktop_napi dylib on aarch64-darwin. Use LLVM's
                # Mach-O linker for the Rust outputs until nixpkgs updates ld.
                nativeBuildInputs =
                  old.nativeBuildInputs ++ final.lib.optionals final.stdenv.hostPlatform.isDarwin [ final.lld ];
                env =
                  old.env
                  // final.lib.optionalAttrs final.stdenv.hostPlatform.isDarwin {
                    RUSTFLAGS = "-C link-arg=-fuse-ld=lld";
                  };
                # Upstream pins an older Electron 43. Update the manifest after npmDeps
                # has been assembled so nixpkgs' runtime-major check accepts the
                # maintained Electron used by electron-builder.
                preBuild = ''
                  substituteInPlace package.json \
                    --replace-fail '"electron": "43.2.0"' '"electron": "${electron.version}"'
                ''
                + old.preBuild;
              });
          # fj prints its first-run keys-file notice to stdout, and nixpkgs
          # captures that into every generated completion script, so fish runs
          # `Could` as a command. Drop the line until upstream sends it to stderr.
          forgejo-cli = prev.forgejo-cli.overrideAttrs (old: {
            postInstall = old.postInstall + ''
              sed -i '/^Could not find keys file/d' \
                $out/share/bash-completion/completions/fj.bash \
                $out/share/fish/vendor_completions.d/fj.fish \
                $out/share/zsh/site-functions/_fj
            '';
          });
          # sesh runs mockery during its build, and mockery 3.8.0's x/tools
          # can't read Go 1.27.2's export data. sesh's go.mod only needs Go
          # 1.26, so build it and its mockery there until mockery catches up.
          sesh = prev.sesh.override { buildGo127Module = final.buildGo126Module; };
        }
      )
    ]
    ++ extras;

  mkHomeManagerModule =
    {
      homeConfig,
      extraSpecialArgs ? { },
      extraSharedModules ? [ ],
    }:
    {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        extraSpecialArgs = {
          inherit inputs palette typography;
        }
        // extraSpecialArgs;
        users.shane = import homeConfig;
        sharedModules = [
          nixvim.homeModules.nixvim
          catppuccin.homeModules.catppuccin
          (
            { lib, ... }:
            {
              catppuccin.autoEnable = lib.mkDefault false;
            }
          )
          nix-index-database.homeModules.nix-index
        ]
        ++ extraSharedModules;
      };
    };
}
