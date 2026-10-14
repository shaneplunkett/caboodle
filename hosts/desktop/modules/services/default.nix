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
    gvfs = {
      enable = true;
      package = pkgs.gvfs;
    };
    udisks2.enable = true;
    gnome.gnome-keyring.enable = true;
    gnome.at-spi2-core.enable = true;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };

  users.users.shane.openssh.authorizedKeys.keyFiles = [
    ../../../../modules/workstation/authorized-keys
  ];

}
