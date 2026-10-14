{
  fetchFromGitHub,
  nix-update-script,
  vimUtils,
}:

vimUtils.buildVimPlugin rec {
  pname = "xcodebuild-nvim";
  version = "7.3.0";

  src = fetchFromGitHub {
    owner = "wojciech-kulik";
    repo = "xcodebuild.nvim";
    rev = "v${version}";
    hash = "sha256-83TvWtLaHrYGvbdu4P7AwJ8/NeOiCrIW4Qa9bj/kMY4=";
  };

  nvimRequireCheck = "xcodebuild";

  passthru.updateScript = nix-update-script { };
}
