{ palette, ... }:
{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      palette = "catppuccin_mocha";
      palettes.catppuccin_mocha = palette.withHash;

      character = {
        success_symbol = "[[󰄛](teal) ❯](mauve)";
        error_symbol = "[[󰄛](maroon) ❯](mauve)";
        vimcmd_symbol = "[󰄛 ❮](subtext1)";
      };

      directory = {
        truncation_length = 4;
        style = "bold lavender";
      };

      git_branch = {
        style = "bold mauve";
        symbol = " ";
      };

      git_status = {
        style = "bold peach";
      };

      cmd_duration = {
        format = "[󰥔 \$duration](\$style)";
        style = "fg:subtext0";
        min_time = 2000;
      };

      nix_shell = {
        style = "sky";
        symbol = " ";
      };

      golang = {
        style = "sky";
        symbol = " ";
      };

      nodejs = {
        style = "green";
        symbol = " ";
      };

      python = {
        style = "yellow";
        symbol = " ";
      };

      rust = {
        style = "peach";
        symbol = "󱘗 ";
      };

      terraform = {
        style = "lavender";
        symbol = "󱁢 ";
      };

    };
  };
}
