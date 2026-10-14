{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    hidden-bar
    signal-desktop
  ];
}
