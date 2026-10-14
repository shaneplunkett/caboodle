_: {

  plugins = {

    todo-comments = {
      enable = true;
    };

  };

  keymaps = [
    {
      mode = "n";
      key = "]t";
      action.__raw = ''
        function()
          require("todo-comments").jump_next()
        end
      '';
      options.desc = "Next Todo Comment";
    }
    {
      mode = "n";
      key = "[t";
      action.__raw = ''
        function()
          require("todo-comments").jump_prev()
        end
      '';
      options.desc = "Previous Todo Comment";
    }
    {
      mode = "n";
      key = "<leader>st";
      action = "<cmd>TodoTelescope<cr>";
      options.desc = "Todo";
    }
    {
      mode = "n";
      key = "<leader>sT";
      action = "<cmd>TodoTelescope keywords=TODO,FIX,FIXME<cr>";
      options.desc = "Todo/Fix/Fixme";
    }
  ];
}
