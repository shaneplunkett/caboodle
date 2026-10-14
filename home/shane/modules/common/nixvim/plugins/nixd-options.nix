# Not a module: nixd evaluates this at runtime against whichever flake the
# open file belongs to (see lsp.nix). It picks the configuration matching
# this machine's hostname, or the first one on this platform, and returns the
# package set and option sets nixd should complete from.
{ root, hostname }:
let
  flake = builtins.getFlake root;
  isDarwin = builtins.match ".*-darwin" builtins.currentSystem != null;
  nixos = flake.nixosConfigurations or { };
  darwin = flake.darwinConfigurations or { };
  # Colmena nodes carry the deployed hosts' full module set (deployment.*,
  # secrets), so they rank above plain nixosConfigurations.
  colmena = flake.colmenaHive.nodes or { };
  ranked =
    if isDarwin then
      [
        darwin
        colmena
        nixos
      ]
    else
      [
        colmena
        nixos
        darwin
      ];
  first = configs: configs.${builtins.head (builtins.attrNames configs)};
  host =
    let
      named = builtins.filter (configs: configs ? ${hostname}) ranked;
      nonEmpty = builtins.filter (configs: configs != { }) ranked;
    in
    if named != [ ] then
      (builtins.head named).${hostname}
    else if nonEmpty != [ ] then
      first (builtins.head nonEmpty)
    else
      null;

  standaloneHome = flake.homeConfigurations or { };
  homeManager =
    if host != null && host.options ? home-manager then
      host.options.home-manager.users.type.getSubOptions [ ]
    else if standaloneHome != { } then
      (first standaloneHome).options
    else
      { };
in
{
  pkgs =
    if host != null then
      host.pkgs or host.config._module.args.pkgs
    else if flake.inputs ? nixpkgs then
      import flake.inputs.nixpkgs { }
    else
      import <nixpkgs> { };
  system = if host != null then host.options else { };
  home-manager = homeManager;
  nixvim =
    if homeManager ? programs.nixvim then homeManager.programs.nixvim.type.getSubOptions [ ] else { };
}
