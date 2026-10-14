{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  nix-update-script,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libgbm,
  libnotify,
  libpulseaudio,
  libuuid,
  libx11,
  libxscrnsaver,
  libxcomposite,
  libxcursor,
  libxdamage,
  libxext,
  libxfixes,
  libxi,
  libxrandr,
  libxrender,
  libxtst,
  libxcb,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemdLibs,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ytmdesktop-bin";
  version = "2.0.12";

  src = fetchurl {
    url = "https://github.com/ytmdesktop/ytmdesktop/releases/download/v${finalAttrs.version}/youtube-music-desktop-app_${finalAttrs.version}_amd64.deb";
    hash = "sha256-SJTNJ1AA949FKq25JzN6Bj69WwHxP8Pt9bxgPTu20Kg=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libgbm
    libnotify
    libpulseaudio
    libuuid
    libxcb
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemdLibs
    libx11
    libxscrnsaver
    libxcomposite
    libxcursor
    libxdamage
    libxext
    libxfixes
    libxi
    libxrandr
    libxrender
    libxtst
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb --fsys-tarfile "$src" | tar --no-same-owner --no-same-permissions -xf -
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out"/bin "$out"/lib "$out"/share
    cp -r usr/lib/youtube-music-desktop-app "$out"/lib/
    cp -r usr/share/applications usr/share/pixmaps "$out"/share/

    substituteInPlace "$out"/share/applications/youtube-music-desktop-app.desktop \
      --replace-fail "Exec=youtube-music-desktop-app %U" "Exec=ytmdesktop %U"

    makeWrapper "$out"/lib/youtube-music-desktop-app/youtube-music-desktop-app "$out"/bin/ytmdesktop \
      --add-flags "''${NIXOS_OZONE_WL:+''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true}}"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Desktop App for YouTube Music";
    homepage = "https://ytmdesktop.app/";
    changelog = "https://github.com/ytmdesktop/ytmdesktop/releases/tag/v${finalAttrs.version}";
    downloadPage = "https://github.com/ytmdesktop/ytmdesktop/releases";
    license = lib.licenses.gpl3Only;
    mainProgram = "ytmdesktop";
    platforms = [ "x86_64-linux" ];
  };
})
