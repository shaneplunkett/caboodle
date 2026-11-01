{ pkgs, ... }:
{
  imports = [
    ../modules/services/norish
  ];

  environment.etc."sha-279-proof".source = pkgs.runCommand "sha-279-fails-to-build" { } "exit 1";
}
