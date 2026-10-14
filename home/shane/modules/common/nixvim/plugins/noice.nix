_: {
  plugins = {
    noice = {
      enable = true;
      settings = {
        lsp = {
          hover.silent = true;
          override = {
            "vim.lsp.util.convert_input_to_markdown_lines" = true;
            "vim.lsp.util.stylize_markdown" = true;
            "cmp.entry.get_documentation" = true;
          };
        };
        routes = [
          {
            filter = {
              event = "msg_show";
              any = [
                { find = "%d+L, %d+B"; }
                { find = "; after #%d+"; }
                { find = "; before #%d+"; }
                { find = "fewer lines"; }
              ];
            };
            view = "mini";
          }
          {
            filter = {
              event = "notify";
              find = "No information available";
            };
            opts.skip = true;
          }
        ];
        presets = {
          bottom_search = true;
          command_palette = false;
          long_message_to_split = true;
          inc_rename = true;
          lsp_doc_border = true;
        };
        views = {
          cmdline_popup = {
            position = {
              row = 25;
              col = "50%";
            };
            border = {
              style = "rounded";
            };
            size = {
              min_width = 60;
              width = "auto";
              height = "auto";
            };
            win_options = {
              winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder";
            };
          };
          cmdline_popupmenu = {
            relative = "editor";
            position = {
              row = 28;
              col = "50%";
            };
            size = {
              width = 60;
              height = "auto";
              max_height = 15;
            };
            border = {
              style = "rounded";
            };
            win_options = {
              winhighlight = "NormalFloat:NormalFloat,FloatBorder:NoiceCmdlinePopupBorder";
            };
          };
          hover = {
            border = {
              style = "single";
            };
          };
          confirm = {
            border = {
              style = "single";
            };
          };
          popup = {
            border = {
              style = "single";
            };
          };
        };
      };
    };
  };
}
