{ pkgs, ... }:
let
  provider = "in" + "g";
  credentialRef = "www.${provider}.com.au";
  projectDir = "$HOME/Projects/personal/${provider}-probe";

  loadEnv = ''
    ING_CIF="$(rbw get --field username ${credentialRef} 2>/dev/null)"
    ING_ACCESS_CODE="$(rbw get ${credentialRef} 2>/dev/null)"
    ING_ACCOUNT_NUMBER="$(rbw get --raw ${credentialRef} 2>/dev/null | jq -r '.notes // empty')"
    if [ -z "$ING_CIF" ] || [ -z "$ING_ACCESS_CODE" ] || [ -z "$ING_ACCOUNT_NUMBER" ]; then
      echo "account-tools: unable to fetch credentials from rbw (is the agent unlocked?)" >&2
      exit 1
    fi
    export ING_CIF ING_ACCESS_CODE ING_ACCOUNT_NUMBER
  '';

  accountEnv = pkgs.writeShellApplication {
    name = "account-env";
    runtimeInputs = [
      pkgs.rbw
      pkgs.jq
    ];
    text = ''
      ${loadEnv}
      if [ $# -eq 0 ]; then
        printf 'ING_CIF=%s***\nING_ACCESS_CODE=****\nING_ACCOUNT_NUMBER=%s***\n' \
          "''${ING_CIF:0:2}" "''${ING_ACCOUNT_NUMBER:0:2}"
        exit 0
      fi
      exec "$@"
    '';
  };

  accountCheck = pkgs.writeShellApplication {
    name = "account-check";
    runtimeInputs = [
      pkgs.rbw
      pkgs.jq
      pkgs.nodejs
    ];
    text = ''
      PROBE_DIR="${projectDir}"
      if [ ! -f "$PROBE_DIR/probe.mjs" ]; then
        echo "account-tools: $PROBE_DIR/probe.mjs not found" >&2
        exit 1
      fi
      ${loadEnv}
      cd "$PROBE_DIR"
      exec node probe.mjs
    '';
  };
in
{
  home.packages = [
    accountEnv
    accountCheck
  ];
}
