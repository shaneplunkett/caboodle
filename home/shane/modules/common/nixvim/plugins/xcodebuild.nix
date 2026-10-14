{ pkgs, lib, ... }:
let
  xcodebuild-nvim = pkgs.callPackage ../../../../../../pkgs/xcodebuild-nvim { };
in
{
  extraPlugins = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [
    xcodebuild-nvim
  ];

  extraPackages = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    with pkgs;
    [
      xcbeautify
    ]
  );

  extraConfigLua = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin ''
    require("xcodebuild").setup({})
  '';

  keymaps = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [
    {
      mode = "n";
      key = "<leader>Xb";
      action = "<cmd>XcodebuildBuild<cr>";
      options.desc = "Build";
    }
    {
      mode = "n";
      key = "<leader>Xr";
      action = "<cmd>XcodebuildBuildRun<cr>";
      options.desc = "Build & Run";
    }
    {
      mode = "n";
      key = "<leader>Xt";
      action = "<cmd>XcodebuildTest<cr>";
      options.desc = "Run Tests";
    }
    {
      mode = "n";
      key = "<leader>XT";
      action = "<cmd>XcodebuildTestSelected<cr>";
      options.desc = "Run Current Test";
    }
    {
      mode = "n";
      key = "<leader>Xd";
      action = "<cmd>XcodebuildSelectDevice<cr>";
      options.desc = "Pick Device";
    }
    {
      mode = "n";
      key = "<leader>Xs";
      action = "<cmd>XcodebuildSelectScheme<cr>";
      options.desc = "Pick Scheme";
    }
    {
      mode = "n";
      key = "<leader>Xl";
      action = "<cmd>XcodebuildToggleLogs<cr>";
      options.desc = "Toggle Build Logs";
    }
    {
      mode = "n";
      key = "<leader>Xc";
      action = "<cmd>XcodebuildCleanBuild<cr>";
      options.desc = "Clean Build";
    }
    {
      mode = "n";
      key = "<leader>Xp";
      action = "<cmd>XcodebuildShowCurrentConfig<cr>";
      options.desc = "Show Config";
    }
    {
      mode = "n";
      key = "<leader>Xi";
      action = "<cmd>XcodebuildSetup<cr>";
      options.desc = "Setup Project";
    }
  ];
}
