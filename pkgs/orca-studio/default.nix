{
  lib,
  fetchurl,
  appimageTools,
  glib-networking,
  makeWrapper,
  nix-update-script,
}:

let
  version = "02.08.01.55-p6";
in
appimageTools.wrapType2 (finalAttrs: {
  pname = "orca-studio";
  inherit version;

  src = fetchurl {
    url = "https://github.com/jarczakpawel/OrcaStudio/releases/download/v${version}/OrcaStudio_Linux_AppImage_ubuntu24.04_amd64_${version}.AppImage";
    hash = "sha256-fxcjyrFPpDGxcdHoJV8/NkmOkpdHJhEKqTqS8PK5z3U=";
  };

  extraPkgs = pkgs: [
    pkgs.glib-networking
    pkgs.libsoup_3
    pkgs.libwebp
    pkgs.webkitgtk_4_1
  ];

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    install -m 444 -D ${finalAttrs.contents}/com.orcaslicer.OrcaStudio.desktop \
      $out/share/applications/com.orcaslicer.OrcaStudio.desktop
    substituteInPlace $out/share/applications/com.orcaslicer.OrcaStudio.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=orca-studio'

    install -m 444 -D ${finalAttrs.contents}/OrcaStudio.png \
      $out/share/icons/hicolor/192x192/apps/OrcaStudio.png

    wrapProgram $out/bin/orca-studio \
      --prefix GIO_EXTRA_MODULES : ${glib-networking}/lib/gio/modules \
      --set SSL_CERT_FILE /etc/ssl/certs/ca-bundle.crt
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Bambu Studio fork with OrcaSlicer changes and restored BambuNetwork support";
    homepage = "https://github.com/jarczakpawel/OrcaStudio";
    license = lib.licenses.agpl3Only;
    mainProgram = "orca-studio";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
