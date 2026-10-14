{
  fetchFromGitHub,
  glib,
  gtk4,
  gtk4-layer-shell,
  lib,
  nix-update-script,
  pkg-config,
  rustPlatform,
}:
rustPlatform.buildRustPackage {
  pname = "hyprland-preview-share-picker";
  version = "0.2.1-unstable-2026-08-19";

  src = fetchFromGitHub {
    owner = "WhySoBad";
    repo = "hyprland-preview-share-picker";
    rev = "7dc38ae9b835a88923df25b751f56e74989cf7dc";
    hash = "sha256-g6L1Cmj27p3r963JhqB/P3KYTp89+XFGSNYXSCdfM7E=";
    fetchSubmodules = true;
  };

  patches = [ ./readable-monitor-labels.patch ];

  cargoHash = "sha256-AqX9jKj7JLEx1SLefyaWYGbRdk0c3H/NDTIsZy6B6hY=";

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    glib
    gtk4
    gtk4-layer-shell
  ];

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Hyprland screen-share picker with live window and monitor previews";
    homepage = "https://github.com/WhySoBad/hyprland-preview-share-picker";
    license = lib.licenses.mit;
    mainProgram = "hyprland-preview-share-picker";
    platforms = lib.platforms.linux;
  };
}
