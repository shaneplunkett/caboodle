{ pkgs, ... }:
{

  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    home-manager
    gh
    gcc
    zip
    unzip
    psmisc
    python3
    yq-go
    lsof
    wl-clipboard
    openocd

    ffmpeg
    pulseaudio
  ];

}
