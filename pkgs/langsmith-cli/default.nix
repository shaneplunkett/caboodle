{
  lib,
  fetchurl,
  stdenvNoCC,
}:
let
  version = "0.2.47";

  # Only the platforms that get the agent CLI stack: the desktop and the
  # ARM Macs.
  assetBySystem = {
    aarch64-darwin = "langsmith_darwin_arm64.tar.gz";
    x86_64-linux = "langsmith_linux_amd64.tar.gz";
  };

  hashBySystem = {
    aarch64-darwin = "sha256-NfUY/OzG23eElF8f2n1zN78RghBK7WijHq5OclBw/TU=";
    x86_64-linux = "sha256-hDU7/0R3Iry8TWxF761LxkYSVketZXpULl8td3kw7qU=";
  };

  system = stdenvNoCC.hostPlatform.system;
  asset = assetBySystem.${system} or (throw "langsmith-cli: unsupported system '${system}'");
  hash = hashBySystem.${system} or (throw "langsmith-cli: missing hash for '${system}'");
in
stdenvNoCC.mkDerivation {
  pname = "langsmith-cli";
  inherit version;

  src = fetchurl {
    url = "https://github.com/langchain-ai/langsmith-cli/releases/download/v${version}/${asset}";
    inherit hash;
  };

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 langsmith "$out/bin/langsmith"
    install -Dm644 LICENSE "$out/share/licenses/langsmith-cli/LICENSE"
    install -Dm644 README.md "$out/share/doc/langsmith-cli/README.md"
    runHook postInstall
  '';

  meta = {
    description = "LangSmith CLI for querying traces, runs, datasets, and evaluators";
    homepage = "https://github.com/langchain-ai/langsmith-cli";
    license = lib.licenses.mit;
    platforms = builtins.attrNames assetBySystem;
    mainProgram = "langsmith";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
