_: {
  plugins = {
    cmp = {
      enable = true;
      autoEnableSources = true;
      settings = {
        snippet.expand = "function(args) require('luasnip').lsp_expand(args.body) end";
        mapping.__raw = ''
          cmp.mapping.preset.insert({
            -- Navigate completion menu (using same keys as your old config)
            ['<C-k>'] = cmp.mapping.select_prev_item(),
            ['<C-j>'] = cmp.mapping.select_next_item(),

            -- Trigger completion
            ['<C-Space>'] = cmp.mapping.complete(),

            -- Close completion
            ['<C-e>'] = cmp.mapping.abort(),

            -- Accept completion (Tab to accept, Enter without select)
            ['<CR>'] = cmp.mapping.confirm({ select = false }),
            ['<Tab>'] = cmp.mapping.confirm({ select = true }),

            -- Navigate snippet placeholders
            ['<C-f>'] = cmp.mapping(function(fallback)
              local luasnip = require('luasnip')
              if luasnip.jumpable(1) then
                luasnip.jump(1)
              else
                fallback()
              end
            end, { 'i', 's' }),
            ['<C-b>'] = cmp.mapping(function(fallback)
              local luasnip = require('luasnip')
              if luasnip.jumpable(-1) then
                luasnip.jump(-1)
              else
                fallback()
              end
            end, { 'i', 's' }),

            -- Scroll documentation
            ['<C-u>'] = cmp.mapping.scroll_docs(-4),
            ['<C-d>'] = cmp.mapping.scroll_docs(4),
          })
        '';
        sources = [
          { name = "nvim_lsp"; }
          { name = "nvim_lsp_signature_help"; }
          { name = "luasnip"; }
          { name = "path"; }
          { name = "buffer"; }
        ];
        window = {
          completion.__raw = "cmp.config.window.bordered()";
          documentation.__raw = "cmp.config.window.bordered()";
        };
        experimental = {
          ghost_text = true;
        };
      };
    };

    cmp-nvim-lsp-signature-help.enable = true;
    cmp-cmdline.enable = true;

    lspkind = {
      enable = true;
      settings = {
        symbol_map = {
          Copilot = "";
        };
        maxwidth = 50;
        ellipsis_char = "...";
        mode = "symbol_text";
      };
    };
  };

  extraConfigLua = ''
    local cmp = require('cmp')

    -- Setup completion for search
    cmp.setup.cmdline('/', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = {
        { name = 'buffer' },
      },
    })

    -- Setup completion for commands
    cmp.setup.cmdline(':', {
      mapping = cmp.mapping.preset.cmdline(),
      sources = cmp.config.sources({
        { name = 'path' },
      }, {
        { name = 'cmdline' },
      }),
    })
  '';
}
