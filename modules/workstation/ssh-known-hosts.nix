{ lib, ... }:
let
  tailnet = "tail1d49f8.ts.net";

  # Each machine's /etc/ssh/ssh_host_ed25519_key.pub. scripts/remote.sh runs
  # SSH with no terminal, so a host missing from known_hosts can't be
  # accepted at a prompt and the connection just fails. Keyed by the
  # HostKeyAlias names in home/shane/modules/common/ssh.nix.
  hostKeys = {
    desktop = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAJlDrYU+/DRoZfsVRgiAlibwSWfP40SysLgt0Nl+DMr";
    mini-server = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE0d9nOtZXKbdHdTpyqr3sCU3PY3JOYb+quchdDBwZpB";
    shanes-macbook-pro = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG2e8LJxWocIENbQzKoMp3ZyB7oWHdDkBnQMw4OQT+Hb";
  };
in
{
  programs.ssh.knownHosts = lib.mapAttrs (name: publicKey: {
    hostNames = [
      name
      "${name}.${tailnet}"
    ];
    inherit publicKey;
  }) hostKeys;
}
