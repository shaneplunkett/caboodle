{ pkgs, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    package = pkgs.openssh;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 3;
        ControlMaster = "auto";
        ControlPath = "~/.ssh/control-%C";
        ControlPersist = "10m";
      };

      "github.com" = {
        IdentityFile = [ "~/.ssh/id_ed25519" ];
        IdentitiesOnly = true;
      };
    };
  };
}
