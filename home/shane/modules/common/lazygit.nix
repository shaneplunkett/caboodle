{ palette, ... }:
let
  inherit (palette) withHash;
in
{
  xdg.configFile."lazygit/config.yml".text = ''
    gui:
      theme:
        activeBorderColor:
          - '${withHash.mauve}'
          - bold
        inactiveBorderColor:
          - '${withHash.subtext0}'
        optionsTextColor:
          - '${withHash.blue}'
        selectedLineBgColor:
          - '${withHash.surface0}'
        cherryPickedCommitBgColor:
          - '${withHash.surface1}'
        cherryPickedCommitFgColor:
          - '${withHash.mauve}'
        unstagedChangesColor:
          - '${withHash.red}'
        defaultFgColor:
          - '${withHash.text}'
        searchingActiveBorderColor:
          - '${withHash.yellow}'
        authorColors:
          '*': '${withHash.lavender}'
    git:
      overrideGpg: true
    services:
      'forge': 'gitea:git.shaneplunkett.com'
  '';
}
