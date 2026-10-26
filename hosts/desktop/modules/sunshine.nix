{
  config,
  lib,
  pkgs,
  ...
}:
let
  hyprland = config.home-manager.users.shane.wayland.windowManager.hyprland.settings;
  monitors = map (monitor: monitor.output) hyprland.monitor;
  steamWorkspace =
    (lib.findFirst (
      rule: (rule.match.class or null) == "(?i)^steam$"
    ) (throw "No Hyprland window rule puts Steam on a workspace.") hyprland.window_rule).workspace;
  workspaceMonitors = builtins.toJSON (
    map (rule: { inherit (rule) workspace monitor; }) hyprland.workspace_rule
  );
  retainFullscreen =
    enabled:
    "hyprctl eval 'hl.config({ misc = { exit_window_retains_fullscreen = ${lib.boolToString enabled} } })'";
  setMonitors =
    disabled:
    lib.concatMapStrings (monitor: ''
      hyprctl eval 'hl.monitor({ output = "${monitor}", disabled = ${lib.boolToString disabled} })'
    '') monitors;

  stream = pkgs.writeShellApplication {
    name = "sunshine-stream";
    runtimeInputs = [
      config.programs.hyprland.package
      config.programs.steam.package
      pkgs.jq
      pkgs.util-linux
    ];
    text = ''
      present() {
        hyprctl "$1" -j | jq -e --arg match "$2" "any($3 == \$match)" >/dev/null
      }

      start() {
        hyprctl eval "hl.monitor({ output = \"STREAM\", mode = \"''${SUNSHINE_CLIENT_WIDTH}x''${SUNSHINE_CLIENT_HEIGHT}@''${SUNSHINE_CLIENT_FPS}\", position = \"auto\", scale = 1 })"
        hyprctl output create headless STREAM
        for _ in $(seq 50); do
          present monitors STREAM .name && break
          sleep 0.1
        done
        present monitors STREAM .name

        hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "${steamWorkspace}", monitor = "STREAM" })'
        ${setMonitors true}
        hyprctl dispatch 'hl.dsp.focus({ workspace = "${steamWorkspace}" })'
        ${retainFullscreen true}

        setsid -f steam steam://open/bigpicture >/dev/null 2>&1
        for _ in $(seq 100); do
          present clients "Steam Big Picture Mode" .title && break
          sleep 0.1
        done
        hyprctl dispatch 'hl.dsp.focus({ window = "title:^Steam Big Picture Mode$" })' || true
        hyprctl dispatch 'hl.dsp.window.fullscreen({ action = "set" })' || true
      }

      stop() {
        set +e
        setsid -f steam steam://close/bigpicture >/dev/null 2>&1
        ${retainFullscreen (hyprland.misc.exit_window_retains_fullscreen or false)}
        ${setMonitors false}
        hyprctl output remove STREAM
        hyprctl workspaces -j \
          | jq -r --argjson rules '${workspaceMonitors}' \
            '.[] | (.id | tostring) as $id | $rules[] | select(.workspace == $id) | "\(.workspace) \(.monitor)"' \
          | while read -r workspace monitor; do
            hyprctl dispatch "hl.dsp.workspace.move({ workspace = \"$workspace\", monitor = \"$monitor\" })"
          done
        true
      }

      "$1"
    '';
  };
in
{
  environment.systemPackages = [ stream ];

  services.sunshine = {
    enable = true;
    autoStart = true;

    # Hyprland's wlroots capture path works without the broad CAP_SYS_ADMIN
    # capability required by KMS capture.
    capSysAdmin = false;
    openFirewall = false;

    settings = {
      capture = "wlr";
      encoder = "vaapi";
      adapter_name = "/dev/dri/renderD128";

      output_name = "STREAM";

      # Remote access goes through Tailscale rather than router port forwards.
      upnp = "disabled";
      origin_web_ui_allowed = "pc";
      lan_encryption_mode = 2;
      wan_encryption_mode = 2;
    };

    applications.apps = [
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
      {
        name = "Steam";
        image-path = "steam.png";
        prep-cmd = [
          {
            do = "${lib.getExe stream} start";
            undo = "${lib.getExe stream} stop";
          }
        ];
      }
    ];
  };

  # The pinned Sunshine package loads uhid but omits upstream's udev rules.
  # Keep its virtual-controller devices accessible through the same group as
  # /dev/uinput so DS5, Xbox, and Switch controller emulation all work.
  services.udev.extraRules = ''
    KERNEL=="uhid", GROUP="uinput", MODE="0660", TAG+="uaccess"
    KERNEL=="hidraw*", ATTRS{name}=="Sunshine PS5 (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine X-Box One (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine gamepad (virtual) motion sensors*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine Nintendo (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
    SUBSYSTEMS=="input", ATTRS{name}=="Sunshine PS5 (virtual) pad*", GROUP="uinput", MODE="0660", TAG+="uaccess"
  '';

  # Sunshine's package advertises this through modules-load.d, but NixOS does
  # not consume package-provided modules-load files during early boot.
  boot.kernelModules = [ "uhid" ];

  # Moonlight's streaming ports are exposed only on the wired home LAN.
  # tailscale0 is already trusted by networking.nix for remote streaming.
  networking.firewall.interfaces.enp10s0 = {
    allowedTCPPorts = [
      47984
      47989
      48010
    ];
    allowedUDPPorts = [
      47998
      47999
      48000
      48002
      48010
    ];
  };

  # Sunshine uses uinput for remote keyboard, mouse, and controller events.
  users.users.shane.extraGroups = [ "uinput" ];
}
