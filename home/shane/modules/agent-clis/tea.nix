{ pkgs, lib }:

# tea is the one forge login, Shane's, used by her, her agents and Vex Code
# alike. The wrapper rewrites tea's config from rbw on every invocation, so the
# login is defined here instead of by `tea login add` on each machine. ssh_host
# is the `forge` SSH alias the remotes use: Vex Code and tea both match a repo
# to a login through it, and without it neither recognises the forge.
#
# tea stays on 0.16, pinned here so a nixpkgs bump can't move it: 1.0 is
# untagged, needs Gitea 28 and has no Forgejo tests.
let
  forge = "git.shaneplunkett.com";

  tea = pkgs.tea.overrideAttrs (
    finalAttrs: _: {
      version = "0.16.0";
      src = pkgs.fetchFromGitea {
        domain = "gitea.com";
        owner = "gitea";
        repo = "tea";
        tag = "v${finalAttrs.version}";
        hash = "sha256-wAs0L3UOwsyElrQ9n5BKV8rDZHzj42xL11HT1CFre8k=";
      };
      vendorHash = "sha256-QzJai1AmdXz5pYg1SEEFOetWJkkUhDZoQbJkhkz8UD4=";
    }
  );

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

      exec ${lib.getExe tea} "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "tea-shane-${tea.version}";
  paths = [ tea ];
  postBuild = ''
    rm $out/bin/tea
    ln -s ${lib.getExe wrapper} $out/bin/tea
  '';
  meta = tea.meta // {
    mainProgram = "tea";
  };
}
