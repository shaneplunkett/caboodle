_: {
  plugins = {
    neo-tree = {
      enable = true;
      settings = {
        sources = [
          "filesystem"
          "buffers"
          "git_status"
        ];
        open_files_do_not_replace_types = [
          "terminal"
          "Trouble"
          "trouble"
          "qf"
          "Outline"
        ];

        filesystem = {
          filtered_items = {
            visible = true;
            show_hidden_count = true;
            hide_dotfiles = false;
            hide_gitignored = false;
            hide_by_name = [
              ".git"
              ".DS_Store"
              "thumbs.db"
            ];
            never_show = [ ];
          };
          bind_to_cwd = false;
          follow_current_file = {
            enabled = true;
          };
          use_libuv_file_watcher = true;
        };

        window = {
          mappings = {
            "\\" = "close_window";
            "l" = "open";
            "h" = "close_node";
            "<space>" = "none";
            "Y" = {
              __unkeyed-1.__raw = ''
                function(state)
                  local node = state.tree:get_node()
                  local path = node:get_id()
                  vim.fn.setreg("+", path, "c")
                end
              '';
              desc = "Copy Path to Clipboard";
            };
            "O" = {
              __unkeyed-1.__raw = ''
                function(state)
                  require("lazy.util").open(state.tree:get_node().path, { system = true })
                end
              '';
              desc = "Open with System Application";
            };
            "P" = {
              __unkeyed-1 = "toggle_preview";
              config = {
                use_float = false;
              };
            };
          };
        };

        event_handlers = [
          {
            event = "file_opened";
            handler.__raw = ''
              function(file_path)
                require("neo-tree").close_all()
              end
            '';
          }
        ];

        default_component_configs = {
          indent = {
            with_expanders = true;
            expander_collapsed = "";
            expander_expanded = "";
            expander_highlight = "NeoTreeExpander";
          };
          git_status = {
            symbols = {
              unstaged = "󰄱";
              staged = "󰱒";
            };
          };
          symlink_target = {
            enabled = true;
          };
        };
      };
    };
  };
}
