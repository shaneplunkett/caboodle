{
  lib,
  pkgs,
  ...
}:
let
  bluebubblesThemed = pkgs.bluebubbles-themed;

  wrapGtkAppForX11 =
    {
      executable,
      package,
    }:
    pkgs.symlinkJoin {
      name = "${executable}-x11";
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${executable} \
          --set GDK_BACKEND x11 \
          --set GDK_SCALE 1
      '';
    };

  orcaStudioX11 = wrapGtkAppForX11 {
    executable = "orca-studio";
    package = pkgs.orca-studio;
  };

  electronFlags = ''
    --ozone-platform-hint=auto
    --enable-features=WaylandWindowDecorations
    --force-device-scale-factor=1.5
  '';
  chromeFlags = ''
    --ozone-platform-hint=auto
    --enable-features=WaylandWindowDecorations
    --password-store=basic
  '';
in
{
  home.activation.bluebubblesThemePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    prefs="$HOME/.local/share/app.bluebubbles.BlueBubbles/shared_preferences.json"
    mkdir -p "$(dirname "$prefs")"

    # v2 reads unprefixed keys; keep the legacy keys for its first-run migration
    # and for adaptive_theme, which still uses the legacy preferences API.
    if [[ -f "$prefs" ]]; then
      tmp="$(${pkgs.coreutils}/bin/mktemp)"
      ${pkgs.jq}/bin/jq \
        --arg selected "Shane Desktop" \
        --arg adaptive '{"theme_mode":1,"default_theme_mode":1}' \
        'del(."flutter.closeToTray", ."flutter.minimizeToTray", .closeToTray, .minimizeToTray) + {
          "selected-dark": $selected,
          "selected-light": $selected,
          "flutter.selected-dark": $selected,
          "flutter.selected-light": $selected,
          "flutter.adaptive_theme_preferences": $adaptive
        }' "$prefs" > "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$prefs"
    else
      ${pkgs.coreutils}/bin/cat > "$prefs" <<'JSON'
    {
      "selected-dark": "Shane Desktop",
      "selected-light": "Shane Desktop",
      "flutter.selected-dark": "Shane Desktop",
      "flutter.selected-light": "Shane Desktop",
      "flutter.adaptive_theme_preferences": "{\"theme_mode\":1,\"default_theme_mode\":1}"
    }
    JSON
    fi
  '';

  xdg.configFile = {
    "electron-flags.conf".text = electronFlags;
    "electron32-flags.conf".text = electronFlags;
    "electron33-flags.conf".text = electronFlags;
    "electron34-flags.conf".text = electronFlags;
    "chrome-flags.conf".text = chromeFlags;
  };

  home.packages = with pkgs; [
    zip
    xz
    unzip
    p7zip
    signal-desktop
    chatgpt
    claude-desktop
    bluebubblesThemed
    # Temporarily disabled: upstream Snapcraft fetch is timing out during rebuilds.
    # plex-desktop
    ferdium
    mangohud
    protonup-qt
    shadps4-cache-fixed
    ytmdesktop-bin
    libnotify
    imagemagick
    tesseract
    wl-clipboard
    xdg-utils
    orcaStudioX11
    mpv
    vlc
    samrewritten
    bun
    plezy
    megacmd
    yt-dlp
    google-chrome
    slack-themed
    cosmic-ext-calculator
  ];
}
