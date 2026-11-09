[
  { key = "1"; }
  { key = "2"; }
  {
    key = "A";
    scrolling = true;
    classes = [
      "^t3code$"
      "^chatgpt$"
      "^claude(-desktop)?$"
    ];
    macApps = [
      {
        bundleId = "com.github.Electron";
        titleSubstring = "T3 Code";
      }
      "com.openai.codex"
      "com.anthropic.claudefordesktop"
    ];
  }
  {
    key = "B";
    classes = [ "^google-chrome$" ];
    macApps = [ "com.google.Chrome" ];
  }
  {
    key = "T";
    classes = [ "^com\\.mitchellh\\.ghostty$" ];
    macApps = [ "com.mitchellh.ghostty" ];
  }
  {
    key = "I";
    classes = [ "^linear$" ];
    macApps = [ "com.linear" ];
  }
  {
    key = "S";
    scrolling = true;
    classes = [
      "^signal$"
      "(?i)^slack$"
      "^ferdium$"
      "^vesktop$"
      "^bluebubbles$"
    ];
    macApps = [
      "org.whispersystems.signal-desktop"
      "org.ferdium.ferdium-app"
      "com.tinyspeck.slackmacgap"
      "dev.vencord.vesktop"
      "com.apple.MobileSMS"
    ];
  }
  {
    key = "M";
    classes = [
      "^com\\.edde746\\.plezy$"
      "^YouTube Music Desktop App$"
    ];
    macApps = [ "uk.co.wearecocoon.YT-Music" ];
  }
  {
    key = "9";
    secondary = true;
  }
  {
    key = "O";
    classes = [ "^md\\.Obsidian$" ];
    macApps = [ "md.obsidian" ];
  }
  {
    key = "G";
    classes = [
      "(?i)^steam$"
      "^steam_app_.*$"
    ];
    macApps = [
      "com.valvesoftware.steam"
      "com.moonlight-stream.Moonlight"
    ];
  }
  {
    key = "E";
    classes = [ "^mail$" ];
    macApps = [ "com.apple.mail" ];
  }
]
