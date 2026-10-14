{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  nix-update-script,
}:
buildNpmPackage rec {
  pname = "todoist-cli";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "Doist";
    repo = "todoist-cli";
    rev = "v${version}";
    hash = "sha256-3MJ6K17s6tOMLtxJiEYkRaDxCyRMKI31z2kmPwXAyVA=";
  };

  npmDepsHash = "sha256-1OZ7Tj8q3cu4+rT7JDknhSFhHe3fX+sWFuTry83BTOI=";

  npmBuildScript = "build";

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Official Todoist CLI from Doist — agent-friendly with --json/--ndjson output";
    homepage = "https://github.com/Doist/todoist-cli";
    license = lib.licenses.mit;
    mainProgram = "td";
  };
}
