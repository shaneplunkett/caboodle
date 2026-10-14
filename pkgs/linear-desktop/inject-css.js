// Appended to out/main/index.js by the nix build. Runs at module load, before
// app "ready", so every window and webview the app ever creates is covered.
// webContents.insertCSS applies via the devtools protocol, outside the page's
// CSP, so Linear's remote UI cannot block it.
;(() => {
  const { app } = require("electron");
  const fs = require("fs");
  const path = require("path");
  const css = fs.readFileSync(path.join(__dirname, "custom.css"), "utf8");
  app.on("web-contents-created", (_event, contents) => {
    contents.on("dom-ready", () => {
      contents.insertCSS(css).catch(() => {});
    });
  });
})();
