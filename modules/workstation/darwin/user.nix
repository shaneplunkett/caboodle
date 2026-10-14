{ lib, ... }:
let
  # nh's two elevated steps on `nh darwin switch`, run against the out-link
  # in nh's temp dir (/var/folders/…/T/nh-darwinXXXX/result). Passwordless
  # so a switch can run over SSH, where Touch ID can't answer the prompt.
  result = "/var/folders/*/nh-darwin*/result";

  # sudo resolves `env` from PATH; today that's /usr/bin/env, the others
  # cover coreutils landing in the system or home profile later.
  envPrefixes = [
    "/usr/bin/env"
    "/run/current-system/sw/bin/env"
    "/etc/profiles/per-user/shane/bin/env"
  ];

  switchCommands = lib.concatMap (env: [
    "${env} * nix build --no-link --profile /nix/var/nix/profiles/system ${result}"
    "${env} * ${result}/sw/bin/darwin-rebuild activate"
  ]) envPrefixes;
in
{

  users.users.shane.home = "/Users/shane";
  system.primaryUser = "shane";

  security.sudo.extraConfig = ''
    shane ALL=(root) NOPASSWD: ${lib.concatStringsSep ", " switchCommands}
  '';
}
