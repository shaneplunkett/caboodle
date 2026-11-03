{
  coreutils,
  lib,
  procps,
  stdenv,
  writeShellApplication,
}:
writeShellApplication {
  name = "job-started.sh";
  runtimeInputs = [ coreutils ] ++ lib.optional stdenv.hostPlatform.isLinux procps;
  text = builtins.readFile ./job-started.sh;
}
