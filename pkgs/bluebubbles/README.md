# BlueBubbles

Backported from NixOS/nixpkgs commit
[`e1d40648f1ca892c88ecc71e25bd9a691a8315b6`](https://github.com/NixOS/nixpkgs/commit/e1d40648f1ca892c88ecc71e25bd9a691a8315b6)
to update the client without updating the whole desktop package set.
`default.nix` is upstream's `package.nix`; the lock file and ObjectBox helper
files come from the same commit.

For updates, refresh this directory from the upstream package together, including
the Dart lock file, Git dependency hashes and native library versions. A source
version bump alone isn't enough. The local theme lives in `../bluebubbles-themed`.

Once the main nixpkgs pin includes this release, remove this backport and its
`pkgs/default.nix` entry. Keep the separate themed override.
