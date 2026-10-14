{ config, ... }:
{
  home.sessionVariables = {
    TF_PLUGIN_CACHE_DIR = "${config.home.homeDirectory}/.terraform.d/plugin-cache";
  };

  programs.fish.interactiveShellInit = ''
    set -gx TF_PLUGIN_CACHE_DIR $HOME/.terraform.d/plugin-cache
  '';

  home.file.".terraform.d/plugin-cache/.keep".text = "";
}
