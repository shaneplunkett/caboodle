{
  lib,
  pkgs,
  ...
}:
let
  rbw = lib.getExe pkgs.rbw;
in
{
  programs.rbw = {
    enable = true;
    settings = {
      email = "shane@shaneplunkett.com";
      lock_timeout = 604800;
      # Prompts inline in whatever terminal ran rbw, including T3 Code's, on
      # every machine. Anything without a terminal (MCP servers, hooks) can't
      # prompt and fails loudly instead; the rbw-locked session hook tells
      # agents when that will happen.
      pinentry = pkgs.pinentry-tty;
    };
  };

  # Unlock once per desktop session. This used to happen accidentally when the
  # interactive shell fetched an Aikido token; keep it explicit now that the
  # work-only tooling is gone.
  programs.fish.loginShellInit = ''
    if test "$TERM_PROGRAM" = ghostty; and not ${rbw} unlocked >/dev/null 2>&1
      ${rbw} unlock
    end
  '';
}
