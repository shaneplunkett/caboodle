{ config, ... }:
{

  plugins = {

    treesitter = {
      enable = true;
      highlight.enable = true;
      indent.enable = true;
      nixvimInjections = true;
      nixGrammars = true;
      grammarPackages = with config.plugins.treesitter.package.builtGrammars; [
        css
        eex
        elixir
        erlang
        heex
        html
        hyprlang
        javascript
        nix
        python
        svelte
        typescript
        tsx
        terraform
        hcl
        astro
        rust
        ruby
        sql
        glimmer
        c_sharp
        glsl
        prisma
        go
        graphql
        swift
        yaml

      ];
    };

    treesitter-context.enable = true;

    treesitter-textobjects = {
      enable = true;
    };
  };

}
