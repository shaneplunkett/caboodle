_: {
  colorschemes.catppuccin = {
    enable = true;
    settings = {
      flavour = "mocha";

      color_overrides = {
        mocha = {
          mantle = "#1e1e2e";
        };
      };

      # Shift accent from blue/lavender to mauve to match the rest of the system
      custom_highlights.__raw = ''
        function(colors)
          return {
            -- Borders and titles: mauve instead of blue/lavender
            FloatBorder  = { fg = colors.mauve },
            FloatTitle   = { fg = colors.crust, bg = colors.mauve },
            Title        = { fg = colors.mauve, bold = true },
            Directory    = { fg = colors.mauve },

            -- Cursor line number
            CursorLineNr = { fg = colors.mauve },

            -- Search highlights: mauve-based instead of sky-based
            Search       = { bg = colors.mauve,    fg = colors.base },
            IncSearch    = { bg = colors.lavender,  fg = colors.base },
            CurSearch    = { bg = colors.pink,      fg = colors.base },

            -- Popup menu selection
            PmenuSel     = { bg = colors.mauve, fg = colors.base, bold = true },

            -- Neo-tree: mauve accent with contrast
            NeoTreeDirectoryIcon = { fg = colors.mauve },
            NeoTreeDirectoryName = { fg = colors.lavender },
            NeoTreeRootName      = { fg = colors.pink, bold = true, italic = true },
            NeoTreeTabActive     = { bg = colors.base, fg = colors.mauve },
            NeoTreeFileName      = { fg = colors.text },
            NeoTreeGitModified   = { fg = colors.yellow },
            NeoTreeGitUntracked  = { fg = colors.peach },
            NeoTreeIndentMarker  = { fg = colors.surface1 },

            -- Lualine normal mode: mauve instead of blue
            lualine_a_normal = { bg = colors.mauve, fg = colors.base, bold = true },
          }
        end
      '';
    };
  };
}
