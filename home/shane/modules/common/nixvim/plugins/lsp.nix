{ pkgs, ... }:
{

  plugins = {
    lsp-format = {
      enable = true;
    };

    lsp-status = {
      enable = true;
    };

    lsp = {
      enable = true;
      inlayHints = false;
      keymaps = {
        silent = true;
        lspBuf = {
          "<leader>cr" = {
            action = "rename";
            desc = "Rename";
          };
        };
      };
      servers = {

        nixd = {
          enable = true;
          cmd = [
            "nixd"
            "--log=error"
          ];
          settings = {
            formatting.command = [ "nixfmt" ];
          };
          # nixd only takes config from the editor, so point it at the flake
          # each client is rooted in. Outside a flake it keeps its <nixpkgs>
          # defaults.
          extraOptions.before_init.__raw = ''
            function(_, config)
              local root = config.root_dir
              if not root or not vim.uv.fs_stat(root .. "/flake.nix") then
                return
              end
              local probe = string.format(
                "(import ${./nixd-options.nix} { root = %s; hostname = %s; })",
                vim.json.encode(root),
                vim.json.encode((vim.uv.os_gethostname():gsub("%..*", "")))
              )
              config.settings.nixd.nixpkgs = { expr = probe .. ".pkgs" }
              config.settings.nixd.options = {
                system = { expr = probe .. ".system" },
                ["home-manager"] = { expr = probe .. ".home-manager" },
                nixvim = { expr = probe .. ".nixvim" },
              }
            end
          '';
        };

        gopls = {
          enable = true;
          autostart = true;
          settings = {
            gofumpt = true;
            staticcheck = true;
            usePlaceholders = true;
            analyses = {
              unusedparams = true;
              unusedvariable = true;
              shadow = true;
            };
          };
        };
        pyright = {
          enable = true;
          settings = {
            python.analysis = {
              typeCheckingMode = "basic";
            };
          };
        };
        lua_ls = {
          enable = true;
          settings.telemetry.enable = false;
        };
        # High performance Typescript LSP (wrapper around VSCode's TS service)
        vtsls = {
          enable = true;
          # Recommended settings for web dev
          settings = {
            typescript = {
              updateImportsOnFileMove.enabled = "always";
              inlayHints = {
                parameterNames.enabled = "literals";
                parameterTypes.enabled = true;
                variableTypes.enabled = false;
                propertyDeclarationTypes.enabled = true;
                functionLikeReturnTypes.enabled = true;
                enumMemberValues.enabled = true;
              };
            };
            javascript = {
              updateImportsOnFileMove.enabled = "always";
              inlayHints = {
                parameterNames.enabled = "literals";
                parameterTypes.enabled = true;
                variableTypes.enabled = false;
                propertyDeclarationTypes.enabled = true;
                functionLikeReturnTypes.enabled = true;
                enumMemberValues.enabled = true;
              };
            };
            vtsls = {
              enableMoveToFileCodeAction = true;
              autoUseWorkspaceTsdk = true;
              experimental = {
                completion = {
                  enableServerSideFuzzyMatch = true;
                };
              };
            };
          };
        };
        cssls = {
          enable = true;
          settings = {
            css = {
              validate = true;
              lint = {
                unknownAtRules = "ignore";
              };
            };
            scss = {
              validate = true;
              lint = {
                unknownAtRules = "ignore";
              };
            };
            less = {
              validate = true;
              lint = {
                unknownAtRules = "ignore";
              };
            };
          };
        };
        tailwindcss.enable = true;
        html.enable = true;
        bashls.enable = true;
        astro.enable = true;
        dockerls.enable = true;
        terraformls = {
          enable = true;
          extraOptions = {
            init_options = {
              experimentalFeatures = {
                prefillRequiredFields = true;
              };
            };
          };
        };
        jsonls.enable = true;
        yamlls.enable = true;
        phpactor.enable = true;
        ruby_lsp.enable = true;
        sqls.enable = true;
        prismals = {
          enable = true;
          package = pkgs.prisma-language-server;
        };
        glsl_analyzer.enable = true;

        sourcekit = {
          enable = pkgs.stdenv.hostPlatform.isDarwin;
          cmd = [
            "xcrun"
            "sourcekit-lsp"
          ];
          filetypes = [
            "swift"
            "objc"
            "objcpp"
          ];
        };

      };

    };

  };

}
