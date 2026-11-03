{
  curl,
  jq,
  openssl,
  writeShellApplication,
}:
writeShellApplication {
  name = "github-app-token";
  runtimeInputs = [
    curl
    jq
    openssl
  ];
  text = builtins.readFile ./github-app-token.sh;
}
