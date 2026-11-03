{
  callPackage,
  curl,
  jq,
  writeShellApplication,
}:
writeShellApplication {
  name = "github-runner-registration-token";
  runtimeInputs = [
    (callPackage ../../../pkgs/github-app-token { })
    curl
    jq
  ];
  text = builtins.readFile ./registration-token.sh;
}
