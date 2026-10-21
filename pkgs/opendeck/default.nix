{
  lib,
  fetchurl,
  appimageTools,
  nix-update-script,
}:

let
  version = "2.14.2";
in
appimageTools.wrapType2 (finalAttrs: {
  pname = "opendeck";
  inherit version;

  src = fetchurl {
    url = "https://github.com/nekename/OpenDeck/releases/download/v${version}/opendeck_${version}_amd64.AppImage";
    hash = "sha256-4ARSQjMw/PDRvDfEo/4Gbp50z9NqY5Pv/FrPG+oQrMQ=";
  };

  extraInstallCommands = ''
    install -m 444 -D ${finalAttrs.contents}/opendeck.desktop \
      $out/share/applications/opendeck.desktop
    cp -r ${finalAttrs.contents}/usr/share/icons $out/share/icons
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Stream Deck software that runs Elgato and OpenAction plugins";
    homepage = "https://github.com/nekename/OpenDeck";
    license = lib.licenses.gpl3Plus;
    mainProgram = "opendeck";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
