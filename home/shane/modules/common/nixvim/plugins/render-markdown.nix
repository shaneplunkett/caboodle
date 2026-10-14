_: {
  plugins.render-markdown = {
    enable = true;
    settings = {
      anti_conceal.enabled = false;
      heading = {
        sign = false;
        position = "inline";
        icons = [
          "◈ "
          "◆ "
          "◇ "
          "○ "
          "• "
          "· "
        ];
        backgrounds = [
          "RenderMarkdownH1"
          "RenderMarkdownH2"
          "RenderMarkdownH3"
          "RenderMarkdownH4"
          "RenderMarkdownH5"
          "RenderMarkdownH6"
        ];
      };
      code = {
        sign = false;
        position = "right";
      };
      latex.enabled = false;
    };
  };

  # Word-boundary wrapping and narrow sign column for markdown files
  autoCmd = [
    {
      event = "FileType";
      pattern = [ "markdown" ];
      callback.__raw = ''
        function()
          vim.opt_local.wrap = true
          vim.opt_local.linebreak = true
          vim.opt_local.breakindent = true
          vim.opt_local.signcolumn = "no"
        end
      '';
    }
  ];
}
