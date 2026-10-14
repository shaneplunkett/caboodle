{
  config,
  lib,
  pkgs,
  ...
}:
let
  waydroid = pkgs.waydroid-nftables;
  waydroidBin = lib.getExe waydroid;

  waydroidSessionStart = pkgs.writeShellApplication {
    name = "waydroid-session-start";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.systemd
      waydroid
    ];
    text = ''
      set -euo pipefail

      is_running() {
        waydroid status 2>/dev/null | grep -q '^Session:[[:space:]]*RUNNING'
      }

      systemctl --user start waydroid-session.service

      for _ in $(seq 1 60); do
        if is_running; then
          exit 0
        fi
        sleep 1
      done

      echo "Waydroid session did not start." >&2
      waydroid status >&2 || true
      exit 1
    '';
  };

  waydroidProfile = pkgs.writeShellApplication {
    name = "waydroid-profile";
    runtimeInputs = [
      pkgs.android-tools
      pkgs.coreutils
      pkgs.gawk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.systemd
      waydroid
      waydroidSessionStart
    ];
    text = ''
      set -euo pipefail

      profile="''${1:-}"
      case "$profile" in
        phone)
          width=720
          height=1600
          ;;
        landscape)
          width=2456
          height=1290
          ;;
        *)
          echo "usage: waydroid-profile {phone|landscape}" >&2
          exit 2
          ;;
      esac

      waydroid-session-start

      changed=false
      if [[ "$(waydroid prop get persist.waydroid.width)" != "$width" ]]; then
        waydroid prop set persist.waydroid.width "$width"
        changed=true
      fi
      if [[ "$(waydroid prop get persist.waydroid.height)" != "$height" ]]; then
        waydroid prop set persist.waydroid.height "$height"
        changed=true
      fi

      if [[ "$changed" == true ]]; then
        systemctl --user restart waydroid-session.service
        waydroid-session-start
      fi

      ip=""
      for _ in $(seq 1 60); do
        ip="$(waydroid status 2>/dev/null | sed -n 's/^IP address:[[:space:]]*//p')"
        if [[ -n "$ip" && "$ip" != "UNKNOWN" ]]; then
          break
        fi
        sleep 1
      done

      if [[ -z "$ip" || "$ip" == "UNKNOWN" ]]; then
        echo "Waydroid did not acquire an IP address." >&2
        waydroid status >&2 || true
        exit 1
      fi

      waydroid adb connect
      serial="$ip:5555"

      # adb wait-for-device never returns for an unauthorized device, and
      # Waydroid has no window to show Android's "Allow USB debugging?"
      # prompt in, so poll with a limit and name the state instead.
      state=""
      for _ in $(seq 1 30); do
        state="$(adb devices | awk -v serial="$serial" '$1 == serial { print $2 }')"
        if [[ "$state" == device ]]; then
          break
        fi
        sleep 1
      done

      case "$state" in
        device) ;;
        unauthorized)
          echo "Android rejected this machine's adb key. Copy ~/.android/adbkey.pub to ~/.local/share/waydroid/data/misc/adb/adb_keys (mode 640)." >&2
          exit 1
          ;;
        *)
          echo "adb could not reach Waydroid at $serial (state: ''${state:-not connected})." >&2
          exit 1
          ;;
      esac

      android_ready=false
      for _ in $(seq 1 120); do
        if adb -s "$serial" shell dumpsys user 2>/dev/null \
          | grep -q 'State: RUNNING_UNLOCKED'; then
          android_ready=true
          break
        fi
        sleep 0.5
      done

      if [[ "$android_ready" != true ]]; then
        echo "Android user 0 did not finish starting." >&2
        exit 1
      fi

      case "$profile" in
        phone)
          adb -s "$serial" shell wm size 1080x2400
          adb -s "$serial" shell wm density 420
          adb -s "$serial" shell pm disable-user --user 0 \
            com.google.android.googlequicksearchbox >/dev/null
          ;;
        landscape)
          adb -s "$serial" shell wm size reset
          adb -s "$serial" shell wm density reset
          ;;
      esac
    '';
  };

  androidPhone = pkgs.writeShellApplication {
    name = "android-phone";
    runtimeInputs = [
      pkgs.android-tools
      pkgs.coreutils
      pkgs.gnused
      pkgs.hyprland
      pkgs.jq
      pkgs.scrcpy
      waydroid
      waydroidProfile
    ];
    text = ''
      set -euo pipefail

      record=false
      if [[ "''${1:-}" == "--record" ]]; then
        record=true
        shift
      fi

      package="''${1:-}"
      if [[ -z "$package" ]]; then
        echo "usage: android-phone [--record] <android-package>" >&2
        exit 2
      fi
      native_address=""
      record_file=""
      record_args=()

      if [[ "$record" == true ]]; then
        record_dir="${config.xdg.userDirs.videos}/Android"
        mkdir -p "$record_dir"
        record_file="$record_dir/$package-$(date +%Y-%m-%d_%H-%M-%S).mp4"
        record_args+=(--record "$record_file")
      fi

      # Invoked through the trap below.
      # shellcheck disable=SC2329
      cleanup() {
        if [[ -n "$native_address" ]]; then
          hyprctl dispatch closewindow "address:$native_address" >/dev/null 2>&1 || true
        fi
      }
      trap cleanup EXIT INT TERM

      waydroid-profile phone
      waydroid app launch "$package"

      for _ in $(seq 1 100); do
        native_address="$({
          hyprctl clients -j | jq -r --arg class "waydroid.$package" \
            '.[] | select(.class == $class) | .address'
        } | head -n 1)"
        if [[ -n "$native_address" ]]; then
          break
        fi
        sleep 0.1
      done

      if [[ -z "$native_address" ]]; then
        echo "Waydroid did not create a window for $package." >&2
        exit 1
      fi

      hyprctl dispatch movetoworkspacesilent \
        "special:waydroid,address:$native_address" >/dev/null

      ip="$(waydroid status | sed -n 's/^IP address:[[:space:]]*//p')"
      exec_status=0
      scrcpy \
        --serial "$ip:5555" \
        --display-id 0 \
        --window-title "Android Phone - $package" \
        --window-width 540 \
        --window-height 1200 \
        --shortcut-mod rctrl \
        --keyboard sdk \
        --mouse sdk \
        "''${record_args[@]}" \
        --no-audio || exec_status="$?"

      if [[ -n "$record_file" && -f "$record_file" ]]; then
        echo "Recording saved to $record_file"
      fi

      exit "$exec_status"
    '';
  };

  arknights = pkgs.writeShellApplication {
    name = "arknights";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.libnotify
      waydroid
      waydroidProfile
    ];
    text = ''
      set -euo pipefail

      # Launched from the app menu, stderr goes nowhere, so a failure has
      # to show up as a notification.
      log="$(mktemp)"
      status=0
      waydroid-profile landscape 2>"$log" || status=$?
      cat "$log" >&2
      reason="$(tail -n 1 "$log")"
      rm -f "$log"
      if [[ "$status" -ne 0 ]]; then
        notify-send -a Arknights "Arknights didn't start" "$reason"
        exit "$status"
      fi

      if [ ! -e /var/lib/waydroid/overlay/system/lib64/libhoudini.so ] \
        && [ ! -e /var/lib/waydroid/overlay/system/lib64/libndk_translation.so ]; then
        echo "Warning: Waydroid ARM translation overlay was not found; Arknights may not launch." >&2
      fi

      exec waydroid app launch com.YoStarEN.Arknights
    '';
  };

  waydroidFullUi = pkgs.writeShellApplication {
    name = "waydroid-full-ui";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.libnotify
      waydroid
      waydroidSessionStart
    ];
    text = ''
      set -euo pipefail

      # show-full-ui starts its own session when none is running, which
      # fights the systemd unit, so start that first.
      log="$(mktemp)"
      status=0
      waydroid-session-start 2>"$log" || status=$?
      cat "$log" >&2
      reason="$(tail -n 1 "$log")"
      rm -f "$log"
      if [[ "$status" -ne 0 ]]; then
        notify-send -a Waydroid "Waydroid didn't start" "$reason"
        exit "$status"
      fi

      exec waydroid show-full-ui
    '';
  };

  # The image's ClipboardService reads the host clipboard only in
  # getPrimaryClip and hasPrimaryClip. getPrimaryClipDescription and the
  # clip-changed listeners still see Android's own clipboard, and WebViews
  # (Google sign-in among them) go by those, so pasting there does nothing.
  # This types the host clipboard into whichever Android field has focus.
  waydroidPaste = pkgs.writeShellApplication {
    name = "waydroid-paste";
    runtimeInputs = [
      pkgs.android-tools
      pkgs.gnused
      pkgs.libnotify
      pkgs.wl-clipboard
      waydroid
    ];
    text = ''
      set -euo pipefail

      fail() {
        echo "$1" >&2
        notify-send -a Waydroid "Couldn't paste into Waydroid" "$1"
        exit 1
      }

      ip="$(waydroid status 2>/dev/null | sed -n 's/^IP address:[[:space:]]*//p')"
      if [[ -z "$ip" || "$ip" == UNKNOWN ]]; then
        fail "Waydroid isn't running."
      fi
      serial="$ip:5555"
      adb connect "$serial" >/dev/null

      text="$(wl-paste --no-newline --type text/plain 2>/dev/null)" \
        || fail "The clipboard has no text."
      if [[ -z "$text" ]]; then
        fail "The clipboard is empty."
      fi
      if [[ "$text" == *$'\n'* ]]; then
        fail "The clipboard has more than one line; this only types one."
      fi

      # input text turns "%s" into a space and has no escape for it, so
      # send each piece ending in % on its own.
      sq="'"
      script="set -e"$'\n'
      while [[ -n "$text" ]]; do
        if [[ "$text" == *%* ]]; then
          chunk="''${text%%\%*}%"
          text="''${text#*\%}"
        else
          chunk="$text"
          text=""
        fi
        script+="input text $sq''${chunk//$sq/$sq\\$sq$sq}$sq"$'\n'
      done

      # Over stdin, so the text never shows in the host's process list.
      adb -s "$serial" shell -T <<<"$script" >/dev/null 2>&1 \
        || fail "Android couldn't type that text (it only takes plain ASCII)."
    '';
  };
in
{
  home = {
    packages = [
      androidPhone
      arknights
      waydroidFullUi
      waydroidPaste
      pkgs.android-tools
      pkgs.scrcpy
    ];

    file = {
      ".local/share/applications/arknights.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Arknights
          Exec=${lib.getExe arknights}
          Icon=${config.home.homeDirectory}/.local/share/waydroid/data/icons/com.YoStarEN.Arknights.png
          Categories=Game;X-WayDroid-App;
          X-Purism-FormFactor=Workstation;Mobile;
          Actions=app-settings;

          [Desktop Action app-settings]
          Name=App Settings
          Exec=${waydroidBin} app intent android.settings.APPLICATION_DETAILS_SETTINGS package:com.YoStarEN.Arknights
          Icon=${config.home.homeDirectory}/.local/share/waydroid/data/icons/com.android.settings.png
        '';
      };

      ".local/share/applications/waydroid-full-ui.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Waydroid (full UI)
          Comment=Show the whole Android home screen
          Exec=${lib.getExe waydroidFullUi}
          Icon=waydroid
          Categories=X-WayDroid-App;Utility;
        '';
      };

      ".local/share/applications/waydroid-paste.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Paste into Waydroid
          Comment=Type the clipboard into the focused Android field
          Exec=${lib.getExe waydroidPaste}
          Icon=waydroid
          Categories=X-WayDroid-App;Utility;
        '';
      };

      ".local/share/applications/waydroid.com.YoStarEN.Arknights.desktop" = {
        force = true;
        text = ''
          [Desktop Entry]
          Type=Application
          Name=Arknights
          NoDisplay=true
          Exec=${waydroidBin} app launch com.YoStarEN.Arknights
          Icon=${config.home.homeDirectory}/.local/share/waydroid/data/icons/com.YoStarEN.Arknights.png
          Categories=Game;X-WayDroid-App;
          X-Purism-FormFactor=Workstation;Mobile;
          Actions=app-settings;

          [Desktop Action app-settings]
          Name=App Settings
          Exec=${waydroidBin} app intent android.settings.APPLICATION_DETAILS_SETTINGS package:com.YoStarEN.Arknights
          Icon=${config.home.homeDirectory}/.local/share/waydroid/data/icons/com.android.settings.png
        '';
      };
    };
  };

  systemd.user.services.waydroid-session = {
    Unit = {
      Description = "Waydroid user session";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${waydroidBin} session start";
      ExecStop = "${waydroidBin} session stop";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  wayland.windowManager.hyprland.settings.window_rule = [
    {
      match.title = "^Android Phone - .*$";
      float = true;
      size = [
        540
        1200
      ];
      center = true;
    }
  ];
}
