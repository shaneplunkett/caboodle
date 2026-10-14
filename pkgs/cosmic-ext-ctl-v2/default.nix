{
  cosmic-ext-ctl,
  fetchFromGitHub,
  rustPlatform,
}:

# cosmic-ctl 1.5.0 was built against a pre-v2 libcosmic, so `build-theme`
# reads and writes v1 theme configs while COSMIC 1.9 reads v2. The command
# itself takes its versions from libcosmic, so building the same code against
# a newer libcosmic is the whole fix. This pins cosmic-utils/cosmic-ctl#16
# (libcosmic dc1cf9f, July 2026); drop it once a release includes that bump.
cosmic-ext-ctl.overrideAttrs (
  finalAttrs: _: {
    pname = "cosmic-ext-ctl-v2";
    version = "1.5.0-unstable-2026-09-22";

    src = fetchFromGitHub {
      owner = "Pandapip1";
      repo = "cosmic-ctl";
      rev = "2210d5f9e5308c0df6f9fb5be66f0ae8241a9bc1";
      hash = "sha256-Z7xuEsw8X2BVp+86fPDyEnAinUotQxWi4yMeHwICYz4=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) src;
      hash = "sha256-XKqylax1O1i3ldJDG/RuAblaMWngJQW5UPS91G2R4KA=";
    };

    # versionCheckHook expects the bare version from `cosmic-ctl --version`.
    doInstallCheck = false;
  }
)
