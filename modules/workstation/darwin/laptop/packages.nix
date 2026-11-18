{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    hidden-bar
  ];
}
