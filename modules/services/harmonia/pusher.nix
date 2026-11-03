let
  cache = import ./cache.nix;
  hostKeys = import ../../agenix/host-keys.nix;
in
{
  programs.ssh.knownHosts.${cache.name}.publicKey = hostKeys.cache;
}
