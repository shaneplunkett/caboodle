{ pkgs, lib }:

# fj signs in as the vex bot account, kept apart from Shane's own forge login
# (tea). Vex Code reads fj's keys.json from the default location itself and
# falls back to tea when it holds no login, so the app acts as Shane. This
# wrapper therefore keeps vex's token out of the default location: it writes
# a keys file from rbw into a private data directory on every invocation and
# points fj there.
let
  forge = "git.shaneplunkett.com";

  # fj finds keys.json through directories::ProjectDirs. Linux honours
  # XDG_DATA_HOME; darwin only follows HOME, so it gets a private HOME with
  # links back to the real ssh and git config fj reads for clones.
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
  keysDir =
    if isDarwin then
      "$root/Library/Application Support/forgejo-cli.forgejo-cli"
    else
      "$root/forgejo-cli";
  redirect =
    if isDarwin then
      ''
        for path in .ssh .config .gitconfig; do
          if [ -e "$HOME/$path" ]; then ln -sfn "$HOME/$path" "$root/$path"; fi
        done
        export HOME="$root"
      ''
    else
      ''export XDG_DATA_HOME="$root"'';

  wrapper = pkgs.writeShellApplication {
    name = "fj";
    runtimeInputs = [
      pkgs.rbw
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      token="$(rbw get forge-vex-token 2>/dev/null)" || true
      if [ -z "$token" ]; then
        echo "fj: could not read forge-vex-token from rbw. If rbw is locked, run rbw unlock in a terminal." >&2
        exit 1
      fi

      root="$HOME/.local/share/fj-agent"
      keys_dir="${keysDir}"
      mkdir -p "$keys_dir"
      # default_ssh makes fj clone over SSH; over HTTPS git has no
      # credentials for private repos.
      tmp="$(mktemp "$keys_dir/keys.json.XXXXXX")"
      jq -n --arg token "$token" '{
        hosts: { "${forge}": { type: "Application", token: $token } },
        aliases: { forge: "${forge}" },
        default_ssh: ["${forge}"]
      }' >"$tmp"
      mv -f "$tmp" "$keys_dir/keys.json"

      # Outside a repo fj has no host to talk to, so commands like
      # `fj repo clone owner/name` fall back to the forge.
      export FJ_FALLBACK_HOST="''${FJ_FALLBACK_HOST:-https://${forge}}"

      ${redirect}
      exec ${lib.getExe pkgs.forgejo-cli} "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "fj-agent-${pkgs.forgejo-cli.version}";
  paths = [ pkgs.forgejo-cli ];
  postBuild = ''
    rm $out/bin/fj
    ln -s ${lib.getExe wrapper} $out/bin/fj
  '';
  meta = pkgs.forgejo-cli.meta // {
    mainProgram = "fj";
  };
}
