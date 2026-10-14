{
  inputs,
  lib,
  palette,
  ...
}:
let
  omniwmLib = inputs.omniwm.lib;

  # OmniWM workspaces are named 1-9 and only those have hotkey actions, so
  # the letters are display names keyed in list order.
  workspaceKeys = [
    "1"
    "2"
    "A"
    "B"
    "T"
    "S"
    "M"
    "O"
  ];

  workspaceHotkeys = lib.mergeAttrsList (
    lib.imap0 (index: key: {
      "switchWorkspace.${toString index}" = "Option+${key}";
      "moveToWorkspace.${toString index}" = "Option+Shift+${key}";
    }) workspaceKeys
  );
in
{
  imports = [ inputs.omniwm.homeManagerModules.default ];

  programs.omniwm = {
    enable = true;
    settings = {
      general = {
        defaultLayoutType = "dwindle";
        ipcEnabled = true;
        updateChecksEnabled = false;
      };

      gaps = {
        size = 20.0;
        # outer.top is measured from the top of the display, menu bar
        # included, so it is 20 plus the built-in display's menu bar.
        outer = {
          left = 20.0;
          right = 20.0;
          top = 57.0;
          bottom = 20.0;
        };
      };

      borders.color = omniwmLib.colors.fromHex palette.hex.mauve;

      # On the laptop's notched display the default moves the bar below the
      # menu bar, over the top of the tiled windows. Wrap it around the notch
      # in the menu-bar row instead. Displays without a notch are unaffected.
      workspaceBar.notchMode = "splitActiveLeft";

      workspaces = omniwmLib.workspaces (
        map (key: {
          displayName = key;
          monitorAssignment.type = if key == "2" then "secondary" else "main";
        }) workspaceKeys
      );

      hotkeys = omniwmLib.hotkeys (
        workspaceHotkeys
        // {
          "focus.left" = "Option+H";
          "focus.down" = "Option+J";
          "focus.up" = "Option+K";
          "focus.right" = "Option+L";

          "move.left" = "Option+Shift+H";
          "move.down" = "Option+Shift+J";
          "move.up" = "Option+Shift+K";
          "move.right" = "Option+Shift+L";

          "resizeFocusedWindow.shrink" = "Option+Minus";
          "resizeFocusedWindow.grow" = "Option+Equal";

          # Only eight workspaces, so the ninth digit binding goes.
          "switchWorkspace.8" = "Unassigned";
          "moveToWorkspace.8" = "Unassigned";

          # Defaults that collide with the bindings above.
          "toggleColumnTabbed" = "Unassigned";
          "balanceSizes" = "Unassigned";
          "toggleOverview" = "Unassigned";
          "toggleWorkspaceLayout" = "Unassigned";
          "setContainerPrimarySpan.decrease10Percent" = "Unassigned";
          "setContainerPrimarySpan.increase10Percent" = "Unassigned";
        }
      );
    };
  };
}
