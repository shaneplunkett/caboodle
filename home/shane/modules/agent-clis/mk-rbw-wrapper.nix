{ lib, pkgs }:

# mkRbwWrapper — declarative wrapper-builder for CLIs that need API keys
# fetched from rbw (Bitwarden) at invocation time.
#
# Example:
#   mkRbwWrapper {
#     package = pkgs.tavily-cli;
#     secrets = [ { var = "TAVILY_API_KEY"; entry = "tavily-api-key"; } ];
#   }
{
  package,
  mainProgram ? package.meta.mainProgram or null,
  binaries ? null,
  secrets ? [ ],
  extraEnv ? { },
  name ? null,
  argv0 ? null,
  meta ? { },
}:

let
  rbw = "${pkgs.rbw}/bin/rbw";
  jq = "${pkgs.jq}/bin/jq";

  # Entry names are double-quoted (not single-quoted) so they can be
  # safely nested inside the single-quoted makeWrapper --run script.
  # Entries like "Unifi API Key" contain spaces; single-quote nesting
  # broke shell tokenization at the makeWrapper call site.
  rbwFetch =
    entry: field:
    if field == null then
      ''${rbw} get "${entry}"''
    else if field == "notes" then
      ''${rbw} get --raw "${entry}" | ${jq} -r ".notes // empty"''
    else
      ''${rbw} get --field ${field} "${entry}"'';

  loadSecret =
    secret:
    let
      inherit (secret) var entry;
      field = secret.field or null;
    in
    # Fail loudly: an empty key only resurfaces later as a confusing auth
    # error from the CLI. From a terminal, a locked rbw prompts inline first.
    ''
      if [ -z "''${${var}:-}" ]; then
        ${var}="$(${rbwFetch entry field} 2>/dev/null)" || true
        if [ -z "''${${var}:-}" ]; then
          echo "${lib.head binsToWrap}: could not read ${entry} from rbw. If rbw is locked, run rbw unlock in a terminal." >&2
          exit 1
        fi
        export ${var}
      fi'';

  exportExtra = lib.mapAttrsToList (n: v: ''export ${n}="''${${n}:-${v}}"'') extraEnv;

  envBody = lib.concatStringsSep "\n  " ((map loadSecret secrets) ++ exportExtra);

  argv0Flag = if argv0 != null then "--argv0 ${argv0} \\\n  " else "";

  runScript = ''
    ${argv0Flag}--run '
      ${envBody}
    '
  '';

  binsToWrap =
    if binaries != null then
      binaries
    else if mainProgram != null then
      [ mainProgram ]
    else
      throw "mkRbwWrapper: provide `binaries` or set `package.meta.mainProgram`";

  pkgPname = package.pname or package.name;
  pkgVersion = package.version or "0";
  derivationName = if name != null then name else "${pkgPname}-rbw-${pkgVersion}";

  combinedMeta =
    (package.meta or { })
    // {
      description = (package.meta.description or pkgPname) + " (rbw-wrapped)";
      mainProgram = lib.head binsToWrap;
    }
    // meta;

  symlinkWrapper = pkgs.symlinkJoin {
    name = derivationName;
    paths = [ package ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      ${lib.concatMapStringsSep "\n" (bin: ''
        rm -f $out/bin/${bin}
        makeWrapper ${package}/bin/${bin} $out/bin/${bin} ${runScript}
      '') binsToWrap}
    '';
    meta = combinedMeta;
  };

in
symlinkWrapper
