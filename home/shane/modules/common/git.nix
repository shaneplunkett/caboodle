_: {
  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user = {
        name = "shaneplunkett";
        email = "113661103+shaneplunkett@users.noreply.github.com";
        signingKey = "~/.ssh/id_ed25519.pub";
      };
      gpg = {
        format = "ssh";
      };
      commit = {
        gpgSign = true;
      };
      tag = {
        gpgSign = true;
      };
      init = {
        defaultBranch = "main";
      };
      pull = {
        rebase = true;
      };
      push = {
        autoSetupRemote = true;
      };
      merge = {
        conflictstyle = "diff3";
      };
      core = {
        editor = "nvim";
      };
    };
    ignores = [
      ".direnv/"
      ".go/"
    ];
  };
}
