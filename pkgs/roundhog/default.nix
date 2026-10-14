{
  lib,
  stdenvNoCC,
  fetchurl,
  python3,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "roundhog";
  version = "0.12.3";

  # RoundHog ships inside PostHog's brand package as woff2 only.
  src = fetchurl {
    url = "https://registry.npmjs.org/@posthog/brand/-/brand-${finalAttrs.version}.tgz";
    hash = "sha256-qUvyW7Kkt5ooj5lwidvFTwaIJxwQZH5815lCiq1hXcs=";
  };

  nativeBuildInputs = [
    (python3.withPackages (ps: [
      ps.fonttools
      ps.brotli
    ]))
  ];

  # macOS can't install woff2, so decompress to TTF for both platforms.
  buildPhase = ''
    runHook preBuild
    for f in dist/fonts/*.woff2; do
      fonttools ttLib.woff2 decompress "$f" -o "''${f%.woff2}.ttf"
    done

    # The Medium and SemiBold faces keep Inter's WWS family name (name IDs
    # 21/22). fontconfig reads it as a family, ranks "Inter" high for
    # sans-serif, and serves Medium as the default UI weight. Drop them.
    python3 - dist/fonts/*.ttf <<'PY'
    import sys
    from fontTools.ttLib import TTFont
    for path in sys.argv[1:]:
        font = TTFont(path)
        font["name"].names = [n for n in font["name"].names if n.nameID not in (21, 22)]
        font.save(path)
    PY
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm644 dist/fonts/*.ttf -t $out/share/fonts/truetype
    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "PostHog's rounded brand typeface";
    homepage = "https://posthog.com";
    # PolyForm Strict 1.0.0: personal use only, no redistribution.
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
})
