{ palette, ... }:
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        source = "~/Pictures/logos/nixowo.png";
        type = "kitty-direct";
        height = 18;
        preserveAspectRatio = true;
        padding = {
          top = 3;
          left = 3;
        };
      };

      display = {
        separator = "  ";
        color = {
          keys = palette.withHash.lavender;
          title = palette.withHash.mauve;
        };
      };

      modules = [
        {
          type = "title";
          format = "{user-name}@{host-name}";
          key = " ";
        }
        {
          type = "separator";
          string = "─────────────────────────";
        }
        {
          type = "os";
          key = " ";
          format = "{pretty-name}";
        }
        {
          type = "kernel";
          key = " ";
        }
        {
          type = "uptime";
          key = "󰅐 ";
        }
        {
          type = "packages";
          key = "󰏗 ";
        }
        {
          type = "shell";
          key = " ";
        }
        {
          type = "terminal";
          key = " ";
        }
        {
          type = "wm";
          key = " ";
        }
        {
          type = "cpu";
          key = "󰍛 ";
          format = "{name}";
        }
        {
          type = "gpu";
          key = "󰢮 ";
          format = "{name}";
        }
        {
          type = "memory";
          key = "󰑭 ";
        }
        {
          type = "disk";
          key = "󰋊 ";
          folders = "/";
        }
        {
          type = "separator";
          string = "─────────────────────────";
        }
        {
          type = "colors";
          paddingLeft = 2;
          symbol = "circle";
        }
      ];
    };
  };
}
