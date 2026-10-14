{ pkgs, ... }:
{

  imports = [

    ./amdgpu-dump-collector.nix
    ./noctalia-greeter.nix

  ];

  services = {
    xserver.videoDrivers = [ "amdgpu" ];
    flatpak.enable = true;
    tailscale.enable = true;
    # COSMIC Files mounts drives and network shares through GIO. The module
    # defaults to GNOME's gvfs (online accounts and friends); the plain build
    # is enough.
    gvfs = {
      enable = true;
      package = pkgs.gvfs;
    };
    udisks2.enable = true;
    # Secret Service for apps and Noctalia's own credentials. greetd's PAM
    # stack includes login, which this unlocks with the login password, so
    # gcr's GTK prompt only shows if that unlock fails.
    gnome.gnome-keyring.enable = true;
    # Accessibility bus for T3 SnapShots' "Include app text". Off, NixOS sets
    # NO_AT_BRIDGE=1 and apps publish no text.
    gnome.at-spi2-core.enable = true;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  users.users.shane.openssh.authorizedKeys.keyFiles = [ ../../../../authorized-keys ];

}
