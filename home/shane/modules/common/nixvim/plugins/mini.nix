_: {
  plugins = {
    mini = {
      enable = true;
      modules = {
        ai = {
          n_lines = 500;
          search_method = "cover_or_next";
        };

        surround = {
          mappings = {
            add = "sa";
            delete = "sd";
            find = "sf";
            find_left = "sF";
            highlight = "sh";
            replace = "sr";
            update_n_lines = "sn";
          };
        };

        comment = { };

        pairs = {
          modes = {
            insert = true;
            command = false;
            terminal = false;
          };
        };
      };
    };
  };
}
