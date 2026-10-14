{ pkgs, lib, ... }:
{
  extraPackages =
    with pkgs;
    [
      prettier
      biome
      black
      ruff
      shfmt
      stylua
      rustfmt
      sqlfluff
      nixfmt
      hadolint
      rubocop
      gofumpt
      gotools
      terraform-ls
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
      swiftformat
      swiftlint
    ];

  plugins = {

    conform-nvim = {
      enable = true;
      settings = {
        formatters_by_ft = {
          "_" = [ "trim_whitespace" ];
          css = [ "biome" ];
          html = [ "biome" ];
          svg = [ "biome" ];
          fish = [ "fish_indent" ];
          javascript = [ "prettier" ];
          javascriptreact = [ "prettier" ];
          json = [ "prettier" ];
          jsonc = [ "prettier" ];
          lua = [ "stylua" ];
          nix = [ "nixfmt" ];
          mdx = [ "prettier" ];
          markdown = [ "prettier" ];
          python = [
            "black"
            "ruff"
          ];
          sh = [ "shfmt" ];
          bash = [ "shfmt" ];
          svelte = [ "prettier" ];
          typescript = [ "prettier" ];
          typescriptreact = [ "prettier" ];
          rust = [ "rustfmt" ];
          go = [
            "gofumpt"
            "goimports"
          ];
          astro = [ "prettier" ];
          hcl = [ "terraform_fmt" ];
          terraform = [ "terraform_fmt" ];
          tf = [ "terraform_fmt" ];
          sql = [ "sqlfluff" ];
          pgsql = [ "sqlfluff" ];
          yaml = [ "prettier" ];
          yml = [ "prettier" ];
          ruby = [ "rubocop" ];
          php = [ "php_cs_fixer" ];
          dockerfile = [ "hadolint" ];
          glsl = [ "clang_format" ];
          swift = [ "swiftformat" ];
        };
        format_on_save = ''
          function(bufnr)
          local ignore_filetypes = { "helm" }
          if vim.tbl_contains(ignore_filetypes, vim.bo[bufnr].filetype) then
          return
          end

          -- Disable with a global or buffer-local variable
          if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
          return
          end

          -- Disable autoformat for files in a certain path
          local bufname = vim.api.nvim_buf_get_name(bufnr)
          if bufname:match("/node_modules/") then
          return
          end
          return { timeout_ms = 2000, lsp_fallback = true }
          end
        '';
      };

    };

  };

}
