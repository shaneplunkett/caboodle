{
  asar,
  cctools,
  darwin,
  lib,
  python3,
  slack,
  stdenvNoCC,
}:

# Slack removed custom themes, so restyle it the same way as linear-desktop:
# append a main-process snippet that insertCSS-es a Catppuccin Mocha override
# sheet into every window. OnlyLoadAppFromAsar is enabled, so it must stay an
# asar.
#
# Slack's Linux build ships with the EnableEmbeddedAsarIntegrityValidation fuse
# disabled, so the asar can be repacked freely. Its macOS build has the fuse on,
# so there the repack also updates the fingerprint in Info.plist and re-signs
# the main executable ad hoc. Only that executable changes signature: the
# helpers and frameworks keep Slack's, along with their entitlements.
let
  inherit (stdenvNoCC.hostPlatform) isDarwin;
  app = "$out/Applications/Slack.app";
  fingerprint = action: ''python3 ${./asar-fingerprint.py} ${action} "${app}"'';

  resources = if isDarwin then "${app}/Contents/Resources" else "$out/lib/slack/resources";
  unpackDirs =
    if isDarwin then
      "{node_modules/@tinyspeck,node_modules/bindings,node_modules/cf-prefs,node_modules/electron-native-auth,node_modules/file-handler-info,node_modules/file-uri-to-path,node_modules/macos-notification-state,node_modules/registry-js,node_modules/windows-focus-assist,dist/resources}"
    else
      "{node_modules/registry-js,node_modules/macos-notification-state,node_modules/bindings,node_modules/file-uri-to-path,dist/resources}";
in
slack.overrideAttrs (
  old:
  lib.optionalAttrs isDarwin { dontFixup = true; }
  // {
    pname = "slack-themed";

    nativeBuildInputs =
      (old.nativeBuildInputs or [ ])
      ++ [ asar ]
      ++ lib.optionals isDarwin [
        cctools
        darwin.sigtool
        python3
      ];

    postInstall =
      (old.postInstall or "")
      + lib.optionalString isDarwin ''
        ${fingerprint "check"}
      ''
      + ''
        res="${resources}"

        asar extract "$res/app.asar" app
        cp ${./theme.css} app/dist/custom.css
        printf '\n' >> app/dist/boot.bundle.cjs
        cat ${./inject-css.js} >> app/dist/boot.bundle.cjs

        # Repack, keeping upstream's app.asar.unpacked set: native modules and
        # their JS glue, the call helper entry points Slack spawns as real
        # processes, and the tray/taskbar icons it loads from disk.
        rm -r "$res/app.asar" "$res/app.asar.unpacked"
        asar pack app "$res/app.asar" \
          --unpack-dir "${unpackDirs}" \
          --unpack "*call-*-entry-point.bundle.js"
      ''
      + lib.optionalString isDarwin ''

        ${fingerprint "update"}
        codesign --force --sign - "${app}/Contents/MacOS/Slack"
      '';
  }
)
