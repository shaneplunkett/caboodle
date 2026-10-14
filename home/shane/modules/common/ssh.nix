_:
let
  tailnet = "tail1d49f8.ts.net";

  # Reach a machine by its MagicDNS name. HostKeyAlias keeps known_hosts keyed
  # by the short name, so the saved keys survive however HostName is spelt.
  onTailnet = name: {
    HostName = "${name}.${tailnet}";
    HostKeyAlias = name;
  };

  shaneHost = {
    User = "shane";
    IdentityFile = [ "~/.ssh/id_ed25519" ];
  };
  laptopHost = shaneHost // {
    ServerAliveInterval = 60;
    ServerAliveCountMax = 3;
    RequestTTY = "yes";
    RemoteCommand = "fish -l";
  };
in
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        SetEnv = {
          TERM = "xterm-256color";
        };
      };

      "github.com" = {
        IdentityFile = [ "~/.ssh/id_ed25519" ];
        IdentitiesOnly = true;
      };

      forge = {
        ControlMaster = "auto";
        ControlPath = "~/.ssh/control-%C";
        ControlPersist = "10m";
      };

      pve = shaneHost // onTailnet "pve";
      cube = shaneHost // onTailnet "cube";
      mcphub = shaneHost // onTailnet "mcphub";
      proxy = shaneHost // onTailnet "proxy";
      technitium = shaneHost // onTailnet "technitium";
      technitium2 = shaneHost // onTailnet "technitium2";
      desktop = shaneHost // onTailnet "desktop";
      mbp = laptopHost // onTailnet "shanes-macbook-pro";
      mini = laptopHost // onTailnet "mini-server";
    };
  };
}
