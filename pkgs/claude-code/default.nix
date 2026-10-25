{
  stdenv,
  python3,
  claude-code,
}:
if stdenv.hostPlatform.isLinux then
  claude-code.overrideAttrs (prev: {
    nativeBuildInputs = (prev.nativeBuildInputs or [ ]) ++ [ python3 ];
    preFixup = (prev.preFixup or "") + ''
      python3 ${./prompts.py} $out/bin/claude
    '';
  })
else
  claude-code
