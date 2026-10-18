{
  pkgs,
  lib,
  inputs,
}:
{
  skills = inputs.ai-skills.lib.skills.${pkgs.stdenv.hostPlatform.system};
  inherit (inputs.ai-skills.lib) prompts;

  # Ensure XDG_RUNTIME_DIR is set so rbw can reach its agent from non-login
  # contexts such as MCP servers and hooks.
  rbwRuntimeEnv = ''
    if [ -z "''${XDG_RUNTIME_DIR:-}" ]; then
      runtime_dir="/run/user/$(${pkgs.coreutils}/bin/id -u)"
      if [ -d "$runtime_dir" ]; then
        export XDG_RUNTIME_DIR="$runtime_dir"
      fi
    fi
  '';

  inherit (import ./hooks { inherit pkgs lib; }) hooksFor vexHooksFor;

  mkSkillTree =
    {
      dir,
      skills,
      recursive ? false,
    }:
    lib.mapAttrs' (
      name: source:
      lib.nameValuePair "${dir}/${name}" {
        inherit source recursive;
        force = true;
      }
    ) skills;
}
