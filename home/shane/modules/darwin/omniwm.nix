{
  inputs,
  lib,
  palette,
  ...
}:
let
  omniwmLib = inputs.omniwm.lib;

  builtInDisplayUUID = "37D8832A-2D66-02CA-B9F7-8F30A301B230";

  workspaces = import ../../../workspaces.nix;

  matcher = lib.filterAttrs (
    key: _:
    builtins.elem key [
      "bundleId"
      "appNameSubstring"
      "titleSubstring"
      "titleRegex"
      "axRole"
      "axSubrole"
    ]
  );

  ruleMatching = rule: lib.findFirst (other: matcher other == matcher rule);

  workspaceRules = lib.concatLists (
    lib.imap1 (
      index:
      {
        macApps ? [ ],
        ...
      }:
      map (
        app:
        (if builtins.isString app then { bundleId = app; } else app)
        // {
          assignToWorkspace = toString index;
        }
      ) macApps
    ) workspaces
  );

  defaultAppRules = (fromTOML (builtins.readFile "${inputs.omniwm}/settings-defaults.toml")).appRules;

  workspaceHotkeys = lib.mergeAttrsList (
    lib.imap0 (index: { key, ... }: {
      "switchWorkspace.${toString index}" = "Option+${key}";
      "moveToWorkspace.${toString index}" = "Option+Shift+${key}";
    }) workspaces
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

      focus.followsWindowToMonitor = true;

      gaps = {
        size = 20.0;
        fullscreenUsesOuterGaps = true;
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

      monitorBarOverrides = [
        (omniwmLib.monitor.bar "Built-in Retina Display" {
          monitorDisplayUUID = builtInDisplayUUID;
          enabled = false;
        })
      ];

      statusBar.showWorkspaceName = true;

      appRules =
        map (rule: rule // ruleMatching rule { } workspaceRules) defaultAppRules
        ++ map (rule: omniwmLib.appRule rule.bundleId (removeAttrs rule [ "bundleId" ])) (
          builtins.filter (rule: ruleMatching rule null defaultAppRules == null) workspaceRules
        )
        ++ [ (omniwmLib.appRule "com.apple.finder" { layout = "float"; }) ];

      workspaces = omniwmLib.workspaces (
        map (
          {
            key,
            secondary ? false,
            ...
          }:
          {
            displayName = key;
            monitorAssignment.type = if secondary then "secondary" else "main";
          }
        ) workspaces
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

          "closeFocusedWindow" = "Option+Shift+Q";

          "resizeFocusedWindow.shrink" = "Option+Minus";
          "resizeFocusedWindow.grow" = "Option+Equal";

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
