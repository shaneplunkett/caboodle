{
  lib,
  buildGo127Module,
  buildNpmPackage,
  fetchFromGitHub,
}:
let
  version = "0.31.0";

  src = fetchFromGitHub {
    owner = "icereed";
    repo = "paperless-gpt";
    tag = "v${version}";
    hash = "sha256-h4zpHWSpSBzPj6M9ORtx1w68F/ajORSyIUddnAXaQl0=";
  };

  web-app = buildNpmPackage {
    pname = "paperless-gpt-web-app";
    inherit version src;
    sourceRoot = "${src.name}/web-app";
    npmFlags = [ "--ignore-scripts" ];
    postPatch = ''
      substituteInPlace vite.config.ts \
        --replace-fail "import react from '@vitejs/plugin-react-swc';" "" \
        --replace-fail "plugins: [react()]," ""
    '';
    npmDepsHash = "sha256-6ZkO5pVQfJKYGpgUEKS/AXy/bfuot8cOJ2o+Z087HWM=";
    installPhase = ''
      runHook preInstall
      cp -r dist $out
      runHook postInstall
    '';
  };
in
buildGo127Module {
  pname = "paperless-gpt";
  inherit version src;
  vendorHash = "sha256-PAGZjn8xOsEVNi+JbdgILmDLo1GjK4bBbri/gDKGEh0=";

  preBuild = ''
    cp -r ${web-app} web-app/dist
    substituteInPlace version.go \
      --replace-fail devVersion ${version} \
      --replace-fail devCommit v${version}
  '';

  doCheck = false;

  postInstall = ''
    mkdir -p $out/share/paperless-gpt
    cp -r default_prompts $out/share/paperless-gpt/
  '';

  passthru = { inherit web-app; };

  meta = {
    description = "LLM-powered OCR, titles and tags for Paperless-ngx";
    homepage = "https://github.com/icereed/paperless-gpt";
    license = lib.licenses.mit;
    mainProgram = "paperless-gpt";
    platforms = lib.platforms.linux;
  };
}
