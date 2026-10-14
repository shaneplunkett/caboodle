{
  lib,
  buildNpmPackage,
  fetchurl,
}:
buildNpmPackage rec {
  pname = "browserbase-cli";
  version = "0.5.7";

  src = fetchurl {
    url = "https://registry.npmjs.org/@browserbasehq/cli/-/cli-${version}.tgz";
    hash = "sha256-4zBNpQI8bkhusdcYwHCUrXWaRm/CGOTMV1o/8v9SVFk=";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-ZIcpm4WholV4zqRB7Zacnr45AzJHTI4gYZNPDpe2BSQ=";
  npmDepsFetcherVersion = 2;

  makeCacheWritable = true;
  npmFlags = [ "--legacy-peer-deps" ];

  dontNpmBuild = true;

  meta = {
    description = "Browserbase CLI — bb command for browser sessions, fetch, search, and functions";
    homepage = "https://github.com/browserbase/cli";
    license = lib.licenses.mit;
    mainProgram = "bb";
  };
}
