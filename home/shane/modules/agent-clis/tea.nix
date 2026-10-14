{ pkgs, lib }:

# tea is Shane's own forge login, and Vex Code acts through it (see fj.nix).
# The wrapper rewrites tea's config from rbw on every invocation, so the login
# is defined here instead of by `tea login add` on each machine. ssh_host is
# the `forge` SSH alias the remotes use: Vex Code and tea both match a repo to
# a login through it, and without it neither recognises the forge.
let
  forge = "git.shaneplunkett.com";

  # tea reads its config through adrg/xdg, which defaults to Application
  # Support on darwin. The wrapper writes there rather than redirecting
  # XDG_CONFIG_HOME, which would follow tea into the editor and git it runs.
  configHome =
    if pkgs.stdenv.hostPlatform.isDarwin then "$HOME/Library/Application Support" else "$HOME/.config";

  wrapper = pkgs.writeShellApplication {
    name = "tea";
    runtimeInputs = [
      pkgs.rbw
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      token="$(rbw get forge_token_shane 2>/dev/null)" || true
      if [ -z "$token" ]; then
        echo "tea: could not read forge_token_shane from rbw. If rbw is locked, run rbw unlock in a terminal." >&2
        exit 1
      fi

      # YAML is a superset of JSON, so jq can write the config safely.
      config_dir="''${XDG_CONFIG_HOME:-${configHome}}/tea"
      mkdir -p "$config_dir"
      tmp="$(mktemp "$config_dir/config.yml.XXXXXX")"
      jq -n --arg token "$token" '{
        logins: [{
          name: "me",
          url: "https://${forge}",
          token: $token,
          default: true,
          ssh_host: "forge",
          user: "metrokitten"
        }],
        preferences: { editor: false, flag_defaults: { remote: "" } }
      }' >"$tmp"
      mv -f "$tmp" "$config_dir/config.yml"

      exec ${lib.getExe pkgs.tea} "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "tea-shane-${pkgs.tea.version}";
  paths = [ pkgs.tea ];
  postBuild = ''
    rm $out/bin/tea
    ln -s ${lib.getExe wrapper} $out/bin/tea
  '';
  meta = pkgs.tea.meta // {
    mainProgram = "tea";
  };
}
