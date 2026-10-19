{
  lib,
  fetchurl,
  appimageTools,
  glib-networking,
  makeWrapper,
}:

let
  version = "02.08.02.61";
  build = "20260820225108";
in
appimageTools.wrapType2 (finalAttrs: {
  pname = "bambu-studio-bin";
  inherit version;

  src = fetchurl {
    url = "https://github.com/bambulab/BambuStudio/releases/download/v${version}/BambuStudio_ubuntu24.04-v${version}-${build}.AppImage";
    hash = "sha256-1QGxA/rFQkUT7A6Na8FF+zBxneLH2U1zINcjdAyBp/0=";
  };

  extraPkgs = pkgs: [
    pkgs.glib-networking
    pkgs.libsoup_3
    pkgs.libwebp
    pkgs.webkitgtk_4_1
  ];

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    mv $out/bin/bambu-studio-bin $out/bin/bambu-studio

    install -m 444 -D ${finalAttrs.contents}/BambuStudio.desktop \
      $out/share/applications/BambuStudio.desktop
    substituteInPlace $out/share/applications/BambuStudio.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=bambu-studio'

    install -m 444 -D ${finalAttrs.contents}/BambuStudio.png \
      $out/share/icons/hicolor/192x192/apps/BambuStudio.png

    wrapProgram $out/bin/bambu-studio \
      --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules \
      --set SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt
  '';

  meta = {
    description = "Official Bambu Lab slicer, from its prebuilt AppImage";
    homepage = "https://github.com/bambulab/BambuStudio";
    license = lib.licenses.agpl3Only;
    mainProgram = "bambu-studio";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
