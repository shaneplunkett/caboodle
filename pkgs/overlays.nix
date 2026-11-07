{ inputs }:
let
  mkProjectPackages =
    system: pkgs:
    import ./. {
      inherit pkgs;
      vexCodeSrc = inputs.vex-code;
      isLinux = inputs.nixpkgs.lib.hasSuffix "-linux" system;
      isDarwin = inputs.nixpkgs.lib.hasSuffix "-darwin" system;
      isX86Linux = system == "x86_64-linux";
    };
in
[
  (
    _final: prev:
    let
      inherit (prev.stdenv.hostPlatform) system;
      aiPackages = inputs.llm-agents.packages.${system} or { };
    in
    (prev.lib.optionalAttrs (builtins.hasAttr "codex" aiPackages) {
      inherit (aiPackages) codex;
    })
    // (prev.lib.optionalAttrs (builtins.hasAttr "claude-code" aiPackages) {
      claude-code = prev.callPackage ./claude-code { inherit (aiPackages) claude-code; };
    })
    // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
      inherit (aiPackages) chatgpt claude-desktop;
    }
  )
  (final: prev: mkProjectPackages prev.stdenv.hostPlatform.system final)
  (final: prev: {
    sesh = prev.sesh.override { buildGo127Module = final.buildGo126Module; };
  })
]
