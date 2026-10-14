{
  asar,
  copyDesktopItems,
  curl,
  electron_43,
  fetchurl,
  gnugrep,
  lib,
  makeDesktopItem,
  makeWrapper,
  nix-update,
  p7zip,
  replaceVars,
  typography,
  stdenv,
  writeShellApplication,
}:
let
  version = "1.32.4";

  desktopItem = makeDesktopItem {
    name = "linear";
    desktopName = "Linear";
    comment = "Issue tracking and project planning";
    exec = "linear-desktop %U";
    icon = "linear";
    categories = [ "Office" ];
    mimeTypes = [ "x-scheme-handler/linear" ];
    startupWMClass = "linear";
  };

  updateScript = writeShellApplication {
    name = "update-linear-desktop";
    runtimeInputs = [
      curl
      gnugrep
      nix-update
    ];
    text = ''
      version="$(curl --fail --silent --show-error --head https://releases.linear.app/windows \
        | grep --only-matching --perl-regexp 'filename="Linear Setup \K[0-9.]+(?=\.exe")')"
      exec nix-update --flake linear-desktop --version "$version"
    '';
  };
in
stdenv.mkDerivation {
  pname = "linear-desktop";
  inherit version;

  # Linear only ships Windows and macOS desktop builds. The Windows NSIS
  # installer wraps a plain Electron app with no native modules (its only
  # bundled dependency is @electron/remote), so the app.asar runs unmodified
  # on Linux under nixpkgs' maintained Electron.
  src = fetchurl {
    name = "Linear-Setup-${version}.exe";
    url = "https://releases.linear.app/Linear%20Setup%20${version}.exe";
    hash = "sha256-Y2LN/AU6xbGTIC/jXZLT7D7OxIpL57CIdItCJlehabQ=";
  };

  dontUnpack = true;

  nativeBuildInputs = [
    asar
    copyDesktopItems
    makeWrapper
    p7zip
  ];

  desktopItems = [ desktopItem ];

  buildPhase = ''
    runHook preBuild

    mkdir installer app-bundle
    7z x -y "$src" -oinstaller >/dev/null
    7z x -y 'installer/$PLUGINSDIR/app-64.7z' -oapp-bundle >/dev/null

    # Linear has no font (or similar appearance) settings, so inject our own
    # CSS into every window from the main process. The bundle ends in plain
    # code with no trailing newline, hence the printf guard.
    asar extract app-bundle/resources/app.asar app
    cp ${replaceVars ./custom.css { inherit (typography) ui code; }} app/out/main/custom.css
    printf '\n' >> app/out/main/index.js
    cat ${./inject-css.js} >> app/out/main/index.js

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/linear"
    cp -a app "$out/share/linear/app"
    install -Dm644 ${./icon.png} "$out/share/icons/hicolor/512x512/apps/linear.png"

    # electron-updater sees an unpackaged app and skips update checks, so the
    # Windows-only auto-update path never runs.
    makeWrapper ${electron_43}/bin/electron "$out/bin/linear-desktop" \
      --unset ELECTRON_RUN_AS_NODE \
      --set ELECTRON_OZONE_PLATFORM_HINT auto \
      --add-flags "$out/share/linear/app" \
      --add-flags "--ozone-platform-hint=auto" \
      --add-flags "--enable-features=WaylandWindowDecorations"

    runHook postInstall
  '';

  passthru = {
    inherit updateScript;
  };

  meta = {
    description = "Issue tracking and project planning (unofficial Linux package)";
    homepage = "https://linear.app/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "linear-desktop";
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
