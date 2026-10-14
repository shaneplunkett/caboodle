_: {
  plugins.undotree = {
    enable = true;
    settings = {
      WindowLayout = 2;
      DiffAutoOpen = true;
      SetFocusWhenToggle = true;
    };
  };

  keymaps = [
    {
      mode = "n";
      key = "<leader>du";
      action = "<cmd>UndotreeToggle<CR>";
      options.desc = "Undotree";
    }
  ];
}
