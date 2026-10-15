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
  ];

  _module.args.aiHelpers = import ./lib.nix { inherit pkgs lib inputs; };
}
