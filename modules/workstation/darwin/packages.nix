{
  pkgs,
  ...
}:
{
  environment.systemPackages = with pkgs; [
    vim
    home-manager
    google-chrome
    gh
    docker
    docker-compose
    colima
  ];
}
