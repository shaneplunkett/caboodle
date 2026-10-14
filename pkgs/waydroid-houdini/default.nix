{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
# Intel's ARM translation layer for Waydroid's Android 13 image, laid out
# as the overlay's system partition. Each libhoudini build stops working
# on a hardcoded date: the one waydroid_script installed expired on
# 2026-09-01, and this one runs until about 2028-07-01. When ARM apps hang
# at their splash again, look for a newer commit upstream.
stdenvNoCC.mkDerivation {
  pname = "waydroid-houdini";
  version = "14.0.0-unstable-2026-09-05";

  # Pinned to the commit waydroid_script installs for Android 13.
  src = fetchFromGitHub {
    owner = "supremegamers";
    repo = "vendor_intel_proprietary_houdini";
    rev = "2f8f088671182e17e67321e098e8411a3972a628";
    hash = "sha256-eXkgwP3n5y2XDRB4yDEivpWvhZuPlvUy5/hjALt6cFs=";
  };

  # Android binaries: patching or stripping them for the host breaks them.
  dontFixup = true;

  # Upstream's houdini.rc reads binfmt entries from /vendor, but the overlay
  # puts them under /system, so use waydroid_script's rc instead.
  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r prebuilts $out/system
    install -m 644 ${./houdini.rc} $out/system/etc/init/houdini.rc
    runHook postInstall
  '';

  meta = {
    description = "libhoudini ARM translation for the Waydroid overlay";
    homepage = "https://github.com/supremegamers/vendor_intel_proprietary_houdini";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
