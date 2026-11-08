{ config, ... }:
{
  home.file = {
    ".terraformrc".text = ''
      plugin_cache_dir = "${config.home.homeDirectory}/.terraform.d/plugin-cache"
    '';
    ".terraform.d/plugin-cache/.keep".text = "";
  };
}
