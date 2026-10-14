{
  lib,
  stdenvNoCC,
  fetchurl,
  undmg,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bluebubbles-server";
  version = "1.9.9";

  src = fetchurl {
    url = "https://github.com/BlueBubblesApp/bluebubbles-server/releases/download/v${finalAttrs.version}/BlueBubbles-${finalAttrs.version}-arm64.dmg";
    hash = "sha256-+v1lDIg/UudJSmYl5FJJ8hRNGXN4pNVxQ8z2GYuy6GI=";
  };

  nativeBuildInputs = [ undmg ];

  sourceRoot = "BlueBubbles.app";

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/Applications/BlueBubbles.app
    cp -R . $out/Applications/BlueBubbles.app
    runHook postInstall
  '';

  meta = {
    description = "Server that forwards iMessages to BlueBubbles clients";
    homepage = "https://bluebubbles.app";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "aarch64-darwin" ];
  };
})
