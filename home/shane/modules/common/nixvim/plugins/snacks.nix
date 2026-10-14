_: {
  plugins.snacks = {
    enable = true;
    settings = {
      bigfile.enable = true;
      animate.enable = false;
      indent.enable = true;
      input.enable = true;
      scope.enable = true;
      scroll.enable = true;
      statuscolumn.enable = true;
      words.enable = true;

      notifier = {
        enable = true;
        timeout = 3000;
        top_down = false;
        border = "rounded";
      };
      dashboard = {
        enabled = true;
        preset = {
          header = ''

             ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠋⠀⢀⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⠀⠈⠉⠉⠙⠛⠛⠻⢿⣿⡿⠟⠁⠀⣀⣴⣿⣿⣿⣿⣿⠟
             ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⠀⠀⢀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠛⣉⣡⠀⣠⣴⣶⣶⣦⠄⣀⡀⠀⠀⠀⣠⣾⣿⣿⣿⣿⣿⡿⢃⣾
             ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⣾⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⣠⣾⡟⢡⣾⣿⣿⣿⡿⢋⣴⣿⡿⢀⣴⣾⣿⣿⣿⣿⣿⣿⣿⢡⣾⣿
             ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠃⠀⢻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠃⣼⣿⡟⣰⣿⣿⣿⣿⠏⣰⣿⣿⠟⣠⣿⣿⣿⣿⣿⣿⣿⣿⣿⡇⢚⣛⢿
             ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠏⠀⣠⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣟⠸⣿⠟⢰⣿⣿⣿⣿⠃⣾⣿⣿⠏⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢋⣾
             ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠿⠻⠻⠃⠀⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡄⢉⣴⣿⣿⣿⣿⡇⠘⣿⣿⠋⣼⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣧⡘⣿
             ⣿⣿⣿⣿⣿⣿⣿⣿⡿⠿⠿⣿⣿⣿⣿⠁⢀⣀⠀⢀⣾⣿⣿⣿⣿⣿⣿⠟⠉⠉⠉⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣦⣤⣤⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣌
             ⣿⣿⣿⣿⣿⣿⡿⠁⣀⣤⡀⠀⠈⠻⢿⠀⣼⣿⣷⣿⣿⣿⣿⣿⣿⡿⠁⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
             ⣿⣿⣿⠟⠛⠙⠃⠀⣿⣿⣿⠀⠀⠀⠀⠀⠙⠿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⣾⣿⣿⡿⠿⠿⠿⠿⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠛⠁⠀⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿
             ⣿⠟⠁⢀⣴⣶⣶⣾⣿⣿⣿⣿⣶⡐⢦⣄⠀⠀⠈⠛⢿⣿⣿⣿⣿⡀⠀⠀⠀⠀⢀⣼⡿⢛⣩⣴⣶⣶⣶⣶⣶⣶⣭⣙⠻⣿⣿⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠘⣿⣿⣿⣿⣿⣿
             ⠁⠀⣴⣿⣿⣿⣿⠿⠿⣿⣿⣿⣿⣿⣦⡙⠻⣶⣄⡀⠀⠈⠙⢿⣿⣷⣦⣤⣤⣴⣿⡏⣠⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⣌⠻⣿⣿⣿⠀⠀⠀⠀⠀⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿
             ⠀⢸⣿⣿⣿⠋⣠⠔⠀⠀⠻⣿⣿⣿⣿⢉⡳⢦⣉⠛⢷⣤⣀⠀⠈⠙⠿⣿⣿⣿⣿⢸⣿⡄⠻⣿⣿⠟⡈⣿⣿⣿⣿⣿⢉⣿⣧⢹⣿⣿⣄⠀⠀⠀⠀⠀⠀⠀⢠⣿⣿⣿⣿⣿⣿
             ⠀⢸⣿⣿⡇⠠⡇⠀⠀⠀⠀⣿⣿⣿⣿⢸⣿⣷⣤⣙⠢⢌⡛⠷⣤⣄⠀⠈⠙⠿⣿⣿⣿⣿⣷⣦⣴⣾⣿⣤⣙⣛⣛⣥⣾⣿⣿⡌⣿⣿⣿⣷⣤⣀⣀⣀⣠⣴⣿⣿⣿⣿⣿⣿⣿
             ⠀⢸⣿⣿⣷⡀⠡⠀⠀⠀⣰⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣦⣌⡓⠤⣙⣿⣦⡄⠀⠈⠙⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⢡⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
             ⠀⢸⣿⣿⣿⣿⣶⣤⣴⣾⣿⣿⣿⣿⣿⢸⣿⣿⣿⣿⣿⣿⣿⣿⣷⣾⣿⣿⣷⠀⣶⡄⠀⠈⠙⠿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡿⢃⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
            ⠀ ⢸⣿⣿⣿⣿⣿⠟⠻⣿⣿⡏⣉⣭⣭⡘⠻⢿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⣿⡇⢸⡇⢠⡀⠈⠙⠋⠉⠉⠉⠉⠛⠫⣴⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
            ⠀⢸ ⣿⣿⠛⣿⣿⣀⣀⣾⡿⢀⣿⣿⣿⢻⣷⣦⢈⡙⠻⢿⣿⣿⣿⣿⣿⣿⣿⠀⣿⡇⢸⡇⢸⣿⠀⣦⠀⠀⠶⣶⣦⣀⠀⠘⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
            ⠀⢸⣿ ⣿⣦⣈⡛⠿⠟⣋⣤⣾⣿⣿⣿⣸⣿⣿⢸⡇⢰⡆⢈⡙⠻⢿⣿⣿⣿⠀⢿⡇⢸⡇⢸⣿⢠⣿⡇⣿⡆⢈⡙⠻⠧⠀⢹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
            ⠀⠀⣝⠛ ⢿⣿⣿⣿⣿⣿⣿⠟⣁⠀⠀⢈⠛⠿⢸⣇⢸⡇⢸⡇⣶⣦⣌⡙⠻⢄⡀⠁⠘⠇⠘⣿⢸⣿⡇⣿⡇⢸⡛⠷⣦⣄⠀⠹⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿

          '';
        };
        sections = [

          { section = "header"; }
          {
            section = "keys";
            gap = 1;
            padding = 1;
          }

        ];
      };
      styles = {
        notification = {
          wo = {
            wrap = true;
          };

        };

      };
    };
  };

  keymaps = [
    # --- Top Pickers & Navigation ---
    {
      mode = "n";
      key = "<leader><space>";
      action.__raw = ''
        function()
          Snacks.picker.smart()
        end
      '';
      options.desc = "Smart Find Files";
    }
    {
      mode = "n";
      key = "<leader>,";
      action.__raw = ''
        function()
          Snacks.picker.buffers()
        end
      '';
      options.desc = "Buffers";
    }

    # --- Search ---
    {
      mode = "n";
      key = "<leader>sg";
      action.__raw = ''
        function()
          Snacks.picker.grep()
        end
      '';
      options.desc = "Search Grep";
    }

    # --- LSP Integration (Kickstart.nvim style) ---
    {
      mode = "n";
      key = "<leader>cd";
      action.__raw = ''
        function()
          Snacks.picker.lsp_definitions()
        end
      '';
      options.desc = "Definition";
    }
    {
      mode = "n";
      key = "<leader>cR";
      action.__raw = ''
        function()
          Snacks.picker.lsp_references()
        end
      '';
      options.desc = "References";
    }
    {
      mode = "n";
      key = "<leader>ci";
      action.__raw = ''
        function()
          Snacks.picker.lsp_implementations()
        end
      '';
      options.desc = "Implementation";
    }
    {
      mode = "n";
      key = "<leader>D";
      action.__raw = ''
        function()
          Snacks.picker.lsp_type_definitions()
        end
      '';
      options.desc = "Type Definition";
    }
    {
      mode = "n";
      key = "<leader>ds";
      action.__raw = ''
        function()
          Snacks.picker.lsp_symbols()
        end
      '';
      options.desc = "Document Symbols";
    }
    {
      mode = "n";
      key = "<leader>ws";
      action.__raw = ''
        function()
          Snacks.picker.lsp_workspace_symbols()
        end
      '';
      options.desc = "Workspace Symbols";
    }
    {
      mode = "n";
      key = "<leader>ca";
      action.__raw = ''
        function()
          vim.lsp.buf.code_action()
        end
      '';
      options.desc = "Code Action";
    }
    {
      mode = "n";
      key = "K";
      action.__raw = ''
        function()
          vim.lsp.buf.hover()
        end
      '';
      options.desc = "Hover";
    }
    {
      mode = "n";
      key = "<leader>xx";
      action.__raw = ''
        function()
          Snacks.picker.diagnostics()
        end
      '';
      options.desc = "Diagnostics (Snacks)";
    }
    {
      mode = "n";
      key = "<leader>xX";
      action.__raw = ''
        function()
          Snacks.picker.diagnostics_buffer()
        end
      '';
      options.desc = "Buffer Diagnostics (Snacks)";
    }

    # --- Git Integration ---
    {
      mode = [
        "n"
        "v"
      ];
      key = "<leader>gB";
      action.__raw = ''
        function()
          Snacks.gitbrowse()
        end
      '';
      options.desc = "Git Browse";
    }
    {
      mode = "n";
      key = "<leader>gg";
      action.__raw = ''
        function()
          Snacks.lazygit()
        end
      '';
      options.desc = "Lazygit";
    }

    # --- UI & Utilities ---
    {
      mode = "n";
      key = "<leader>uh";
      action.__raw = ''
        function()
          Snacks.toggle.inlay_hints():toggle()
        end
      '';
      options.desc = "Toggle Inlay Hints";
    }
    {
      mode = "n";
      key = "<leader>z";
      action.__raw = ''
        function()
          Snacks.zen()
        end
      '';
      options.desc = "Toggle Zen Mode";
    }
    {
      mode = "n";
      key = "<leader>Z";
      action.__raw = ''
        function()
          Snacks.zen.zoom()
        end
      '';
      options.desc = "Toggle Zoom";
    }
    {
      mode = "n";
      key = "<leader>un";
      action.__raw = ''
        function()
          Snacks.notifier.hide()
        end
      '';
      options.desc = "Dismiss All Notifications";
    }
    {
      mode = "n";
      key = "<leader>bd";
      action.__raw = ''
        function()
          Snacks.bufdelete()
        end
      '';
      options.desc = "Delete Buffer";
    }

    # --- Scratch Buffers ---
    {
      mode = "n";
      key = "<leader>.";
      action.__raw = ''
        function()
          Snacks.scratch()
        end
      '';
      options.desc = "Toggle Scratch Buffer";
    }
    {
      mode = "n";
      key = "<leader>S";
      action.__raw = ''
        function()
          Snacks.scratch.select()
        end
      '';
      options.desc = "Select Scratch Buffer";
    }

    # --- Terminal ---
    {
      mode = "n";
      key = "<c-/>";
      action.__raw = ''
        function()
          Snacks.terminal()
        end
      '';
      options.desc = "Toggle Terminal";
    }
    {
      mode = "n";
      key = "<c-_>";
      action.__raw = ''
        function()
          Snacks.terminal()
        end
      '';
      options.desc = "which_key_ignore";
    }
    {
      mode = [
        "n"
        "t"
      ];
      key = "]]";
      action.__raw = ''
        function()
          Snacks.words.jump(vim.v.count1)
        end
      '';
      options.desc = "Next Reference";
    }
    {
      mode = [
        "n"
        "t"
      ];
      key = "[[";
      action.__raw = ''
        function()
          Snacks.words.jump(-vim.v.count1)
        end
      '';
      options.desc = "Prev Reference";
    }
  ];
}
