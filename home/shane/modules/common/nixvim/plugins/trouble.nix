_: {
  plugins = {
    trouble = {
      enable = true;
      settings = {
        multiline = true;
      };
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>xt";
      action = "<cmd>Trouble todo toggle<cr>";
      options.desc = "Todo (Trouble)";
    }
    {
      mode = "n";
      key = "<leader>xT";
      action = "<cmd>Trouble todo toggle filter = {tag = {TODO,FIX,FIXME}}<cr>";
      options.desc = "Todo/Fix/Fixme (Trouble)";
    }
  ];
}
