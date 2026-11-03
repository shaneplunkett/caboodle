let
  cache = import ./cache.nix;
in
{
  nix.settings = {
    substituters = [ cache.url ];
    trusted-public-keys = [ cache.publicKey ];
    connect-timeout = 5;
    fallback = true;
  };
}
