{ pkgs, ... }:
{
  extraPackages = with pkgs; [
    shellcheck
    tflint
    statix
    deadnix
  ];

  plugins.lint = {
    enable = true;
    lintersByFt = {
      sh = [ "shellcheck" ];
      bash = [ "shellcheck" ];
      nix = [
        "statix"
        "deadnix"
      ];
      terraform = [ "tflint" ];
      hcl = [ "tflint" ];
      tf = [ "tflint" ];
    };
    autoCmd = {
      event = [
        "BufReadPost"
        "BufWritePost"
        "InsertLeave"
      ];
      callback.__raw = ''
        function()
          require("lint").try_lint()
        end
      '';
    };
  };
}
