{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    ./mcp
    ./cc
    ./codex
    ./vex-code.nix
  ];

  _module.args.aiHelpers = import ./lib.nix { inherit pkgs lib inputs; };
}
