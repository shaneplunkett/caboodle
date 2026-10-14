{
  asar,
  slack,
}:

# Slack removed custom themes, so restyle it the same way as linear-desktop:
# append a main-process snippet that insertCSS-es a Catppuccin Mocha override
# sheet into every window. Slack's Linux build ships with the
# EnableEmbeddedAsarIntegrityValidation fuse disabled, so the asar can be
# repacked freely; OnlyLoadAppFromAsar is enabled, so it must stay an asar.
slack.overrideAttrs (old: {
  pname = "slack-themed";

  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ asar ];

  postInstall = (old.postInstall or "") + ''
    res="$out/lib/slack/resources"

    asar extract "$res/app.asar" app
    cp ${./theme.css} app/dist/custom.css
    printf '\n' >> app/dist/boot.bundle.cjs
    cat ${./inject-css.js} >> app/dist/boot.bundle.cjs

    # Repack, keeping upstream's app.asar.unpacked set: native modules and
    # their JS glue, the call helper entry points Slack spawns as real
    # processes, and the tray/taskbar icons it loads from disk.
    rm -r "$res/app.asar" "$res/app.asar.unpacked"
    asar pack app "$res/app.asar" \
      --unpack-dir "{node_modules/registry-js,node_modules/macos-notification-state,node_modules/bindings,node_modules/file-uri-to-path,dist/resources}" \
      --unpack "*call-*-entry-point.bundle.js"
  '';
})
